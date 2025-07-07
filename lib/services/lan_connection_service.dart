import 'dart:async';
import 'dart:io';

/// Robust LAN connection service for two devices (host/server and client).
/// Handles connection, reconnection, and message streaming.
/// Designed for interoperability between platforms (Linux, Android, etc.).
class LanConnectionService {
  ServerSocket? _serverSocket;
  Socket? _socket;

  // Public getters for UI/other access
  Socket? get socket => _socket;
  ServerSocket? get serverSocket => _serverSocket;

  final StreamController<String> _receivedController =
      StreamController<String>.broadcast();

  /// Stream of incoming messages (one per line).
  Stream<String> get onReceived => _receivedController.stream;

  /// Returns true if a socket connection is active.
  bool get isConnected => _socket != null;

  /// Start as host/server. Returns the listening port.
  Future<int> startAsServer({int port = 4040}) async {
    await dispose(); // Clean up any previous state
    _serverSocket =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    _serverSocket!.listen(_handleIncomingSocket, onError: _handleServerError);
    return _serverSocket!.port;
  }

  /// Connect as client to a given host IP and port, with retry logic.
  Future<void> connectToServer(String hostIp, int port,
      {int retries = 3}) async {
    await dispose(); // Clean up any previous state
    int attempt = 0;
    while (attempt < retries) {
      try {
        _socket = await Socket.connect(hostIp, port,
            timeout: const Duration(seconds: 10));
        _socket!.listen(
          _handleData,
          onDone: _onSocketDone,
          onError: _handleSocketError,
          cancelOnError: true,
        );
        return;
      } on SocketException catch (_) {
        attempt++;
        if (attempt >= retries) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Send a message string to the connected peer.
  void send(String message) {
    if (_socket != null) {
      try {
        _socket!.write('$message\n');
      } catch (_) {
        // Optionally handle send errors
      }
    }
  }

  /// Handle a new incoming client connection (for host/server).
  void _handleIncomingSocket(Socket socket) {
    _socket?.destroy(); // Drop any previous socket
    _socket = socket;
    _socket!.listen(
      _handleData,
      onDone: _onSocketDone,
      onError: _handleSocketError,
      cancelOnError: true,
    );
  }

  /// Handle incoming data from the peer.
  void _handleData(List<int> data) {
    final raw = String.fromCharCodes(data);
    // Split in case multiple messages arrive together
    for (final msg in raw.split('\n')) {
      final trimmed = msg.trim();
      if (trimmed.isNotEmpty) {
        _receivedController.add(trimmed);
      }
    }
  }

  void _onSocketDone() {
    _socket?.destroy();
    _socket = null;
  }

  void _handleSocketError(Object error) {
    // Optionally log or handle socket errors
    _onSocketDone();
  }

  void _handleServerError(Object error) {
    // Optionally log or handle server errors
    dispose();
  }

  /// Cleanly close all resources.
  Future<void> dispose() async {
    try {
      await _serverSocket?.close();
    } catch (_) {}
    try {
      _socket?.destroy();
    } catch (_) {}
    _serverSocket = null;
    _socket = null;
    // Do NOT close the _receivedController here if you want to reconnect/reuse!
    // Only close this when the whole app is shutting down.
  }
}
