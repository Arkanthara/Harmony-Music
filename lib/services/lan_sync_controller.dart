import 'package:get/get.dart';
import 'lan_connection_service.dart';
import 'lan_sync_service.dart';

/// Represents the LAN role of this device.
enum LanRole { none, host, client }

/// Controller to globally manage LAN music sync state and services.
/// Accessible anywhere via `Get.find<LanSyncController>()`.
class LanSyncController extends GetxController {
  /// The underlying LAN connection service (socket).
  LanConnectionService? _conn;

  /// The sync service for sending/receiving commands and songs.
  LanSyncService? _sync;

  /// Current role: host, client, or none.
  final Rx<LanRole> role = LanRole.none.obs;

  /// Whether the LAN connection is active.
  final RxBool connected = false.obs;

  /// Get the current connection if available.
  LanConnectionService? get conn => _conn;

  /// Get the current sync service if available.
  LanSyncService? get sync => _sync;

  /// Setup as host (call after successful server start).
  void setHost(LanConnectionService service) {
    _conn = service;
    _sync = LanSyncService(); // No direct dependency on the connection
    role.value = LanRole.host;
    connected.value = true;
    _sync?.start(); // Start listening for commands
    update();
  }

  /// Setup as client (call after successful client connection).
  void setClient(LanConnectionService service) {
    _conn = service;
    _sync = LanSyncService();
    role.value = LanRole.client;
    connected.value = true;
    _sync?.start();
    update();
  }

  /// Disconnect and clear services/state.
  void disconnect() {
    _conn?.dispose();
    _conn = null;
    _sync = null;
    role.value = LanRole.none;
    connected.value = false;
    update();
  }

  /// Returns true if this device is the host.
  bool get isHost => role.value == LanRole.host;

  /// Returns true if this device is the client.
  bool get isClient => role.value == LanRole.client;

  /// Returns true if currently connected to a peer.
  bool get isConnected => connected.value;
}
