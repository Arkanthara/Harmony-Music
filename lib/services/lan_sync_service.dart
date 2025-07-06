import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/services/audio_handler.dart';
import 'package:harmonymusic/services/lan_sync_controller.dart';
import 'package:harmonymusic/services/lan_connection_service.dart';

/// Service to handle sending/receiving song URL and playback commands for LAN sync.
/// This service always uses the current connection from the global LanSyncController.
class LanSyncService {
  /// Always access the global controller for current connection/services.
  LanSyncController get lanSync => Get.find<LanSyncController>();
  LanConnectionService? get _connection => lanSync.conn;

  /// Send a song URL (and optional title/id) to peer if connected.
  void sendSong(String url, {String? id, String? title}) {
    if (_connection == null) return;
    final msg = 'PLAY_SONG|$url|${id ?? ""}|${title ?? ""}';
    _connection!.send(msg);
  }

  /// Send a control command (PLAY, PAUSE, NEXT, PREV, SEEK).
  void sendCommand(String command, {dynamic data}) {
    if (_connection == null) return;
    if (command == 'SEEK' && data is Duration) {
      _connection!.send('SEEK|${data.inMilliseconds}');
    } else {
      _connection!.send(command);
    }
  }

  /// Start listening for peer commands, should be called after connection is set in controller.
  void start() {
    _connection?.onReceived.listen(_onReceived);
  }

  /// Internal: handle received messages and trigger actions on host.
  void _onReceived(String msg) async {
    final audioHandler = Get.find<MyAudioHandler>();
    if (msg.startsWith('PLAY_SONG|')) {
      final parts = msg.split('|');
      final url = parts[1];
      final id = parts.length > 2 ? parts[2] : '';
      final title = parts.length > 3 ? parts[3] : 'Received Song';
      await _playReceivedSong(url, id: id, title: title);
    } else if (msg == 'PLAY') {
      await audioHandler.play();
    } else if (msg == 'PAUSE') {
      await audioHandler.pause();
    } else if (msg == 'NEXT') {
      await audioHandler.skipToNext();
    } else if (msg == 'PREV') {
      await audioHandler.skipToPrevious();
    } else if (msg.startsWith('SEEK|')) {
      final ms = int.tryParse(msg.split('|')[1]) ?? 0;
      await audioHandler.seek(Duration(milliseconds: ms));
    }
    // Extend as needed for further commands
  }

  /// Use AudioHandler to play the received song.
  Future<void> _playReceivedSong(String url,
      {String? id, String? title}) async {
    final audioHandler = Get.find<MyAudioHandler>();
    final mediaItem = MediaItem(
      id: id ?? url,
      album: '',
      title: title ?? 'Received Song',
      extras: {'url': url},
    );
    await audioHandler.customAction('setSourceNPlay', {'mediaItem': mediaItem});
  }
}
