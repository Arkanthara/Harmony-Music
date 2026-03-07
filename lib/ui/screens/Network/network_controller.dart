import 'package:get/get.dart';

import '/services/network_host_service.dart';
import '/services/network_client_service.dart';
import '/ui/player/player_controller.dart';
import '/utils/helper.dart';

/// Modes the network feature can be in.
enum NetworkMode { none, host, client }

/// GetX controller that manages the Host/Client network feature.
class NetworkController extends GetxController {
  final networkMode = NetworkMode.none.obs;
  final hostIp = RxnString();
  final isHostRunning = false.obs;
  final connectedClients = 0.obs;

  // Discovery
  final isScanning = false.obs;
  final discoveredHosts = <String>[].obs;

  NetworkHostService? _hostService;
  NetworkClientService? _clientService;

  NetworkClientService? get clientService => _clientService;

  // ────────────────────────── Host ──────────────────────────────────────────

  Future<void> startHost() async {
    if (_hostService != null) return;
    _hostService = NetworkHostService(
      onStatusChanged: (running) {
        isHostRunning.value = running;
      },
      onClientCountChanged: (count) {
        connectedClients.value = count;
      },
    );

    await _hostService!.start();
    hostIp.value = await NetworkHostService.getLocalIp();
    networkMode.value = NetworkMode.host;
    printINFO('Host started at ${hostIp.value}');
  }

  Future<void> stopHost() async {
    await _hostService?.stop();
    _hostService = null;
    hostIp.value = null;
    isHostRunning.value = false;
    connectedClients.value = 0;
    networkMode.value = NetworkMode.none;
  }

  // ────────────────────────── Client ────────────────────────────────────────

  NetworkClientService _ensureClient() {
    _clientService ??= NetworkClientService();
    return _clientService!;
  }

  Future<void> connectToHost(String address) async {
    final client = _ensureClient();
    await client.connect(address);
    client.onStateChanged = _syncClientStateToPlayer;
    _syncClientStateToPlayer();
    await client.saveHost(address);
    networkMode.value = NetworkMode.client;
  }

  Future<void> disconnectClient() async {
    _clientService?.onStateChanged = null;
    if (Get.isRegistered<PlayerController>()) {
      Get.find<PlayerController>().disableRemoteClientMode();
    }
    await _clientService?.disconnect();
    networkMode.value = NetworkMode.none;
  }

  List<String> get savedHosts => _ensureClient().getSavedHosts();

  Future<void> removeSavedHost(String address) async {
    await _ensureClient().removeSavedHost(address);
  }

  /// Scans the local network for hosts.
  Future<void> scanForHosts() async {
    isScanning.value = true;
    discoveredHosts.clear();
    final client = _ensureClient();
    try {
      await for (final ip in client.discoverHosts()) {
        if (!discoveredHosts.contains(ip)) {
          discoveredHosts.add(ip);
        }
      }
    } catch (e) {
      printERROR('Discovery error: $e');
    }
    isScanning.value = false;
  }

  void _syncClientStateToPlayer() {
    if (!Get.isRegistered<PlayerController>()) return;
    final client = _clientService;
    if (client == null || !client.isConnected.value) return;

    final player = Get.find<PlayerController>();
    player.enableRemoteClientMode();
    player.applyRemoteClientState(
      song: client.currentSong.value,
      isPlaying: client.isPlaying.value,
      isLoading: client.isLoading.value,
      positionMs: client.position.value,
      bufferedMs: client.buffered.value,
      durationMs: client.duration.value,
      volumeValue: client.volume.value,
      shuffleEnabled: client.shuffleMode.value,
      loopEnabled: client.loopMode.value,
      queueLoopEnabled: client.queueLoopMode.value,
    );
  }

  // ────────────────────────── Cleanup ───────────────────────────────────────

  @override
  void onClose() {
    _hostService?.stop();
    _clientService?.onStateChanged = null;
    _clientService?.disconnect();
    super.onClose();
  }
}
