import 'dart:async';
import 'dart:io';

/// Service to handle LAN connection between two devices.
/// One acts as host (server), the other as client.
class LanConnectionService {
  ServerSocket? _serverSocket;
  Socket? _socket;
  final StreamController<String> _receivedController =
      StreamController.broadcast();

  Stream<String> get onReceived => _receivedController.stream;

  /// Start as server (host). Returns the listening port.
  Future<int> startAsServer({int port = 4040}) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _serverSocket!.listen(_handleIncomingSocket);
    return _serverSocket!.port;
  }

  /// Start as client (connect to hostIP:port).
  Future<void> connectToServer(String hostIp, int port) async {
    _socket = await Socket.connect(hostIp, port);
    _socket!.listen(_handleData, onDone: _onSocketDone, onError: (e) {});
  }

  /// Send message to peer.
  void send(String message) {
    _socket?.write('$message\n');
  }

  /// Internal: when a client connects to our server.
  void _handleIncomingSocket(Socket socket) {
    _socket = socket;
    socket.listen(_handleData, onDone: _onSocketDone, onError: (e) {});
  }

  /// Internal: handle received data.
  void _handleData(List<int> data) {
    final msg = String.fromCharCodes(data).trim();
    _receivedController.add(msg);
  }

  void _onSocketDone() {
    _socket = null;
  }

  void dispose() {
    _serverSocket?.close();
    _socket?.destroy();
    _receivedController.close();
  }

  bool get isConnected => _socket != null;
}
