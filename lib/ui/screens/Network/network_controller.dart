import 'package:get/get.dart';

import '/services/network_host_service.dart';
import '/services/network_client_service.dart';
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
    await client.saveHost(address);
    networkMode.value = NetworkMode.client;
  }

  Future<void> disconnectClient() async {
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

  // ────────────────────────── Cleanup ───────────────────────────────────────

  @override
  void onClose() {
    _hostService?.stop();
    _clientService?.disconnect();
    super.onClose();
  }
}
