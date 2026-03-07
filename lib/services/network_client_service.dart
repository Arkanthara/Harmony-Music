import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/models/media_Item_builder.dart';
import '/utils/helper.dart';

/// Connects to a remote Harmony Music host and allows controlling its playback.
class NetworkClientService {
  WebSocket? _ws;
  final int port;
  Timer? _reconnectTimer;

  /// Called whenever fresh server playback state is received.
  void Function()? onStateChanged;

  // ────────────────────────── Observable state ──────────────────────────────

  final isConnected = false.obs;
  final currentSong = Rxn<MediaItem>();
  final isPlaying = false.obs;
  final isLoading = false.obs;
  final position = 0.obs; // ms
  final buffered = 0.obs; // ms
  final duration = 0.obs; // ms
  final volume = 100.obs;
  final shuffleMode = false.obs;
  final loopMode = false.obs;
  final queueLoopMode = false.obs;
  final queueLength = 0.obs;
  final searchResults = <Map<String, dynamic>>[].obs;
  final isSearching = false.obs;

  String? _hostAddress;

  String? get hostAddress => _hostAddress;

  NetworkClientService({this.port = 8899});

  // ────────────────────────── Saved hosts ───────────────────────────────────

  /// Returns list of previously saved host addresses.
  List<String> getSavedHosts() {
    final box = Hive.box('AppPrefs');
    final raw = box.get('savedNetworkHosts');
    if (raw == null) return [];
    return List<String>.from(raw as List);
  }

  /// Save a host address for quick reconnection.
  Future<void> saveHost(String address) async {
    final box = Hive.box('AppPrefs');
    final hosts = getSavedHosts();
    if (!hosts.contains(address)) {
      hosts.add(address);
      await box.put('savedNetworkHosts', hosts);
    }
  }

  /// Remove a saved host.
  Future<void> removeSavedHost(String address) async {
    final box = Hive.box('AppPrefs');
    final hosts = getSavedHosts();
    hosts.remove(address);
    await box.put('savedNetworkHosts', hosts);
  }

  // ────────────────────────── Discovery ─────────────────────────────────────

  /// Scan the local subnet for hosts running on [port].
  /// Returns a stream of discovered IP addresses.
  Stream<String> discoverHosts({Duration timeout = const Duration(seconds: 3)}) async* {
    String? localIp;
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            localIp = addr.address;
            break;
          }
        }
        if (localIp != null) break;
      }
    } catch (_) {}

    if (localIp == null) return;

    final subnet = localIp.substring(0, localIp.lastIndexOf('.'));
    final futures = <Future<String?>>[];

    for (int i = 1; i < 255; i++) {
      final ip = '$subnet.$i';
      futures.add(_probeHost(ip, timeout));
    }

    // Yield results as they complete.
    for (final future in futures) {
      final result = await future;
      if (result != null) yield result;
    }
  }

  Future<String?> _probeHost(String ip, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      // Verify it's actually our service by hitting /status
      final client = HttpClient();
      client.connectionTimeout = timeout;
      final request = await client.getUrl(Uri.parse('http://$ip:$port/status'));
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      client.close();
      if (data is Map && data.containsKey('isPlaying')) {
        return ip;
      }
    } catch (_) {
      // Not reachable or not a valid host.
    }
    return null;
  }

  // ────────────────────────── Connection ─────────────────────────────────────

  /// Connect to a host at the given [address] (IP or hostname).
  Future<void> connect(String address) async {
    await disconnect();
    _hostAddress = address;

    try {
      _ws = await WebSocket.connect('ws://$address:$port/ws')
          .timeout(const Duration(seconds: 5));
      isConnected.value = true;
      printINFO('Connected to host at $address');

      _ws!.listen(
        _onMessage,
        onDone: () {
          printINFO('Disconnected from host');
          isConnected.value = false;
          _scheduleReconnect();
        },
        onError: (e) {
          printERROR('Client WebSocket error: $e');
          isConnected.value = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      printERROR('Failed to connect to host: $e');
      isConnected.value = false;
      rethrow;
    }
  }

  /// Disconnect from the host.
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _ws?.close();
    _ws = null;
    isConnected.value = false;
    _hostAddress = null;
    currentSong.value = null;
    searchResults.clear();
  }

  void _scheduleReconnect() {
    if (_hostAddress == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_hostAddress != null && !isConnected.value) {
        connect(_hostAddress!).catchError((_) {});
      }
    });
  }

  // ────────────────────────── Incoming messages ─────────────────────────────

  void _onMessage(dynamic rawData) {
    try {
      final msg = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'state':
          _updateState(msg['data'] as Map<String, dynamic>);
          break;
        case 'searchResults':
          final results = (msg['data']?['results'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          searchResults.value = results;
          isSearching.value = false;
          break;
      }
    } catch (e) {
      printERROR('Client message parse error: $e');
    }
  }

  void _updateState(Map<String, dynamic> data) {
    final songJson = data['currentSong'];
    if (songJson != null) {
      try {
        currentSong.value = MediaItemBuilder.fromJson(songJson);
      } catch (_) {
        currentSong.value = null;
      }
    } else {
      currentSong.value = null;
    }

    isPlaying.value = data['isPlaying'] ?? false;
    isLoading.value = data['isLoading'] ?? false;
    position.value = data['position'] ?? 0;
    buffered.value = data['buffered'] ?? 0;
    duration.value = data['duration'] ?? 0;
    volume.value = data['volume'] ?? 100;
    shuffleMode.value = data['shuffleMode'] ?? false;
    loopMode.value = data['loopMode'] ?? false;
    queueLoopMode.value = data['queueLoopMode'] ?? false;
    queueLength.value = data['queueLength'] ?? 0;
    onStateChanged?.call();
  }

  // ────────────────────────── Commands ───────────────────────────────────────

  void _send(Map<String, dynamic> msg) {
    if (_ws == null || !isConnected.value) return;
    _ws!.add(jsonEncode(msg));
  }

  void remotePlay() => _send({'type': 'play'});
  void remotePause() => _send({'type': 'pause'});
  void remoteNext() => _send({'type': 'next'});
  void remotePrev() => _send({'type': 'prev'});

  void remoteSeek(int positionMs) =>
      _send({'type': 'seek', 'data': {'position': positionMs}});

  void remotePlaySong(Map<String, dynamic> songJson) =>
      _send({'type': 'playSong', 'data': {'mediaItem': songJson}});

  void remoteSearch(String query) {
    isSearching.value = true;
    searchResults.clear();
    _send({'type': 'search', 'data': {'query': query}});
  }
}
