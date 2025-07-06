import 'dart:async';
import 'dart:io';

class LanConnectionService {
  ServerSocket? _serverSocket;
  Socket? _socket;
  final StreamController<String> _receivedController =
      StreamController<String>.broadcast();

  Stream<String> get onReceived => _receivedController.stream;
  bool get isConnected => _socket != null;

  /// Start as host/server. Returns the listening port.
  Future<int> startAsServer({int port = 4040}) async {
    await dispose();
    _serverSocket =
        await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
    print(
        'Listening as server on: ${_serverSocket!.address.address}:${_serverSocket!.port}');
    _serverSocket!.listen(_handleIncomingSocket, onError: _handleServerError);
    return _serverSocket!.port;
  }

  /// Connect as client to a given host IP and port, with retry and debug logging.
  Future<void> connectToServer(String hostIp, int port,
      {int retries = 3}) async {
    await dispose();
    int attempt = 0;
    while (attempt < retries) {
      try {
        print(
            'Attempting to connect to $hostIp:$port (try ${attempt + 1}/$retries)...');
        _socket = await Socket.connect(hostIp, port,
            timeout: const Duration(seconds: 10));
        print('Connected to $hostIp:$port!');
        _socket!.listen(
          _handleData,
          onDone: _onSocketDone,
          onError: _handleSocketError,
          cancelOnError: true,
        );
        return;
      } on SocketException catch (e) {
        print('Connection attempt failed: $e');
        attempt++;
        if (attempt >= retries) {
          rethrow;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void send(String message) {
    if (_socket != null) {
      try {
        _socket!.write('$message\n');
      } catch (_) {}
    }
  }

  void _handleIncomingSocket(Socket socket) {
    _socket?.destroy();
    _socket = socket;
    print(
        'Client connected: ${_socket!.remoteAddress.address}:${_socket!.remotePort}');
    _socket!.listen(
      _handleData,
      onDone: _onSocketDone,
      onError: _handleSocketError,
      cancelOnError: true,
    );
  }

  void _handleData(List<int> data) {
    final raw = String.fromCharCodes(data);
    for (final msg in raw.split('\n')) {
      final trimmed = msg.trim();
      if (trimmed.isNotEmpty) {
        _receivedController.add(trimmed);
      }
    }
  }

  void _onSocketDone() {
    print('Socket disconnected.');
    _socket?.destroy();
    _socket = null;
  }

  void _handleSocketError(Object error) {
    print('Socket error: $error');
    _onSocketDone();
  }

  void _handleServerError(Object error) {
    print('Server error: $error');
    dispose();
  }

  Future<void> dispose() async {
    try {
      _serverSocket?.close();
    } catch (_) {}
    try {
      _socket?.destroy();
    } catch (_) {}
    _serverSocket = null;
    _socket = null;
    // Do NOT close the _receivedController if you want reuse in app.
  }
}
