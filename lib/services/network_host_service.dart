import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import '/models/media_Item_builder.dart';
import '/services/music_service.dart';
import '/ui/player/player_controller.dart';
import '/utils/helper.dart';

/// Runs an HTTP + WebSocket server on the host device, exposing
/// playback state and accepting remote commands from clients.
class NetworkHostService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  Timer? _broadcastTimer;
  final int port;

  /// Callback invoked when the server starts / stops.
  final void Function(bool running)? onStatusChanged;

  NetworkHostService({this.port = 8899, this.onStatusChanged});

  bool get isRunning => _server != null;

  /// Returns the device's LAN IPv4 address (best guess).
  static Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      printERROR('Failed to get local IP: $e');
    }
    return null;
  }

  /// Start the server on all IPv4 interfaces.
  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    printINFO('Network host started on port $port');
    onStatusChanged?.call(true);

    _server!.listen(_handleRequest, onError: (e) {
      printERROR('Host server error: $e');
    });

    // Periodically broadcast playback state to all connected WebSocket clients.
    _broadcastTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) => _broadcast());
  }

  /// Stop the server and close all client connections.
  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    for (final ws in _clients) {
      await ws.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    onStatusChanged?.call(false);
    printINFO('Network host stopped');
  }

  // ────────────────────────────── Request handling ──────────────────────────

  void _handleRequest(HttpRequest request) async {
    // Add CORS headers for flexibility.
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Content-Type', 'application/json; charset=utf-8');

    final path = request.uri.path;
    final method = request.method;

    try {
      // WebSocket upgrade
      if (path == '/ws') {
        final ws = await WebSocketTransformer.upgrade(request);
        _onWebSocketConnected(ws);
        return;
      }

      if (method == 'GET' && path == '/status') {
        _handleStatus(request);
      } else if (method == 'GET' && path == '/search') {
        await _handleSearch(request);
      } else if (method == 'POST') {
        await _handleCommand(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Not found'}));
        await request.response.close();
      }
    } catch (e, st) {
      printERROR('Error handling request $path: $e\n$st');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  // ────── GET /status ──────

  void _handleStatus(HttpRequest request) {
    request.response.write(jsonEncode(_buildState()));
    request.response.close();
  }

  // ────── GET /search?q=... ──────

  Future<void> _handleSearch(HttpRequest request) async {
    final query = request.uri.queryParameters['q'];
    if (query == null || query.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'Missing query param q'}));
      await request.response.close();
      return;
    }

    final musicServices = Get.find<MusicServices>();
    final results = await musicServices.search(query, filter: 'songs');
    final songs = (results['content'] as List?)
            ?.map((item) {
              try {
                return MediaItemBuilder.toJson(
                    MediaItemBuilder.fromJson(item));
              } catch (_) {
                return null;
              }
            })
            .whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    request.response.write(jsonEncode({'results': songs}));
    await request.response.close();
  }

  // ────── POST commands ──────

  Future<void> _handleCommand(HttpRequest request) async {
    final path = request.uri.path;
    final player = Get.find<PlayerController>();

    switch (path) {
      case '/play':
        player.play();
        break;
      case '/pause':
        player.pause();
        break;
      case '/next':
        await player.next();
        break;
      case '/prev':
        player.prev();
        break;
      case '/seek':
        final body = await _readBody(request);
        final ms = body['position'] as int?;
        if (ms != null) {
          player.seek(Duration(milliseconds: ms));
        }
        break;
      case '/playSong':
        final body = await _readBody(request);
        final songJson = body['mediaItem'];
        if (songJson != null) {
          final mediaItem = MediaItemBuilder.fromJson(songJson);
          await player.pushSongToQueue(mediaItem);
        }
        break;
      default:
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Unknown command'}));
        await request.response.close();
        return;
    }

    request.response.write(jsonEncode({'ok': true}));
    await request.response.close();
  }

  // ────────────────────────────── WebSocket ─────────────────────────────────

  void _onWebSocketConnected(WebSocket ws) {
    printINFO('WebSocket client connected');
    _clients.add(ws);

    // Send initial state immediately.
    ws.add(jsonEncode({'type': 'state', 'data': _buildState()}));

    ws.listen(
      (data) => _onWebSocketMessage(ws, data),
      onDone: () {
        _clients.remove(ws);
        printINFO('WebSocket client disconnected');
      },
      onError: (e) {
        _clients.remove(ws);
        printERROR('WebSocket error: $e');
      },
    );
  }

  void _onWebSocketMessage(WebSocket ws, dynamic rawData) async {
    try {
      final msg = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      final player = Get.find<PlayerController>();

      switch (type) {
        case 'play':
          player.play();
          break;
        case 'pause':
          player.pause();
          break;
        case 'next':
          await player.next();
          break;
        case 'prev':
          player.prev();
          break;
        case 'seek':
          final ms = msg['data']?['position'] as int?;
          if (ms != null) player.seek(Duration(milliseconds: ms));
          break;
        case 'playSong':
          final songJson = msg['data']?['mediaItem'];
          if (songJson != null) {
            final mediaItem = MediaItemBuilder.fromJson(songJson);
            await player.pushSongToQueue(mediaItem);
          }
          break;
        case 'search':
          final query = msg['data']?['query'] as String?;
          if (query != null && query.isNotEmpty) {
            final musicServices = Get.find<MusicServices>();
            final results =
                await musicServices.search(query, filter: 'songs');
            final songs = (results['content'] as List?)
                    ?.map((item) {
                      try {
                        return MediaItemBuilder.toJson(
                            MediaItemBuilder.fromJson(item));
                      } catch (_) {
                        return null;
                      }
                    })
                    .whereType<Map<String, dynamic>>()
                    .toList() ??
                [];
            ws.add(
                jsonEncode({'type': 'searchResults', 'data': {'results': songs}}));
          }
          break;
      }
    } catch (e) {
      printERROR('WebSocket message error: $e');
    }
  }

  // ────────────────────────────── Broadcast ──────────────────────────────────

  void _broadcast() {
    if (_clients.isEmpty) return;
    final payload = jsonEncode({'type': 'state', 'data': _buildState()});
    for (final ws in List.from(_clients)) {
      try {
        ws.add(payload);
      } catch (_) {
        _clients.remove(ws);
      }
    }
  }

  Map<String, dynamic> _buildState() {
    final player = Get.find<PlayerController>();
    final song = player.currentSong.value;
    final progress = player.progressBarStatus.value;

    return {
      'currentSong': song != null ? MediaItemBuilder.toJson(song) : null,
      'isPlaying': player.buttonState.value == PlayButtonState.playing,
      'isLoading': player.buttonState.value == PlayButtonState.loading,
      'position': progress.current.inMilliseconds,
      'buffered': progress.buffered.inMilliseconds,
      'duration': progress.total.inMilliseconds,
      'volume': player.volume.value,
      'shuffleMode': player.isShuffleModeEnabled.value,
      'loopMode': player.isLoopModeEnabled.value,
      'queueLoopMode': player.isQueueLoopModeEnabled.value,
      'queueLength': player.currentQueue.length,
    };
  }

  // ────────────────────────────── Helpers ────────────────────────────────────

  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.isEmpty) return {};
    return jsonDecode(content) as Map<String, dynamic>;
  }
}
