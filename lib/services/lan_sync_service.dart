import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/services/audio_handler.dart';
import 'package:harmonymusic/services/lan_connection_service.dart';

/// Service to handle sending/receiving song URL and triggering playback.
class LanSyncService {
  final LanConnectionService connection;
  LanSyncService(this.connection) {
    connection.onReceived.listen(_onReceived);
  }

  /// Send a song URL (and optional title/id) to peer.
  void sendSong(String url, {String? id, String? title}) {
    final msg = 'PLAY_SONG|$url|${id ?? ""}|${title ?? ""}';
    connection.send(msg);
  }

  /// Handle incoming messages.
  void _onReceived(String msg) {
    if (msg.startsWith('PLAY_SONG|')) {
      final parts = msg.split('|');
      final url = parts[1];
      final id = parts.length > 2 ? parts[2] : '';
      final title = parts.length > 3 ? parts[3] : 'Received Song';
      _playReceivedSong(url, id: id, title: title);
    }
    // Handle other message types here if needed.
  }

  /// Use AudioHandler to play the received song.
  void _playReceivedSong(String url, {String? id, String? title}) async {
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
