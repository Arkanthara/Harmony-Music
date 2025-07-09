import 'dart:async';
import 'package:get/get.dart';
import 'package:harmonymusic/services/audio_handler.dart';
import 'package:harmonymusic/services/lan_sync_controller.dart';
import 'package:harmonymusic/services/lan_connection_service.dart';
import 'package:harmonymusic/ui/navigator.dart';
import 'package:harmonymusic/ui/player/player_controller.dart';
import 'package:harmonymusic/ui/screens/Search/search_result_screen_controller.dart';
import 'package:harmonymusic/ui/screens/Search/search_screen_controller.dart';

/// Service to handle sending/receiving song URL and playback commands for LAN sync.
class LanSyncService {
  LanSyncService._internal();
  static final LanSyncService _instance = LanSyncService._internal();
  factory LanSyncService() => _instance;
  final searchScreenController = Get.put(SearchScreenController());
  final searchResScrController =
      Get.isRegistered<SearchResultScreenController>()
          ? Get.find<SearchResultScreenController>()
          : null;

  StreamSubscription<String>? _connSub;
  LanConnectionService? _lastConnection;

  LanSyncController get lanSync => Get.find<LanSyncController>();
  LanConnectionService? get _connection => lanSync.conn;

  /// Send a song URL (and optional title/id) to peer if connected.
  void sendSong(String url, {String? id, String? title, String? artist}) {
    String newurl = "https://music.youtube.com/watch?v=$id";
    if (_connection == null) return;
    final msg = 'PLAY_SONG|$newurl|${id ?? ""}|${title ?? ""}|${artist ?? ""}';
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

  /// Start listening for peer commands; call after each (re)connect.
  void start() {
    if (_connection == null) return;
    // Avoid duplicate listeners
    if (_lastConnection == _connection && _connSub != null) return;

    // Cancel previous subscription if switching connections
    _connSub?.cancel();
    _lastConnection = _connection;

    _connSub = _connection!.onReceived.listen(_onReceived);
  }

  /// Internal: handle received messages and trigger actions on host.
  void _onReceived(String msg) async {
    final audioHandler = Get.find<MyAudioHandler>();
    final playerController = Get.find<PlayerController>();
    if (msg.startsWith('PLAY_SONG|')) {
      final parts = msg.split('|');
      if (parts.length < 2) return;
      final url = parts[1];
      final id = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : url;
      final title =
          parts.length > 3 && parts[3].isNotEmpty ? parts[3] : 'Received Song';
      final artist = parts.length > 4 && parts[4].isNotEmpty
          ? parts[4]
          : 'Received Artist';
      await _playReceivedSong(url, id, title, artist);
    } else if (msg.startsWith('SEARCH|')) {
      final parts = msg.split('|');
      if (parts.length < 2) return;
      final search = parts[1];
      if (search.contains("https://")) {
        searchScreenController.filterLinks(Uri.parse(search));
        searchScreenController.reset();
        return;
      }
      Get.toNamed(ScreenNavigationSetup.searchResultScreen,
          id: ScreenNavigationSetup.id, arguments: search);
      searchScreenController.addToHistryQueryList(search);
    } else if (msg.startsWith('TAB|')) {
      final parts = msg.split('|');
      if (parts.length < 2) return;
      final tab = int.parse(parts[1]);
      searchResScrController?.onDestinationSelected(tab);
    } else if (msg == 'PLAY') {
      playerController.play();
    } else if (msg == 'PAUSE') {
      playerController.pause();
    } else if (msg == 'NEXT') {
      playerController.next();
    } else if (msg == 'PREV') {
      playerController.prev();
    } else if (msg.startsWith('SEEK|')) {
      final ms = int.tryParse(msg.split('|')[1]) ?? 0;
      await audioHandler.seek(Duration(milliseconds: ms));
    }
    // Extend as needed for further commands
  }

  /// Use AudioHandler to play the received song.
  Future<void> _playReceivedSong(
      String url, String id, String title, String artist) async {
    String val;
    // if (title == 'Received Song') {
    if (true) {
      searchScreenController.filterLinks(Uri.parse(url));
      searchScreenController.reset();
      return;
    } else if (artist == 'Received Artist') {
      val = title;
    } else {
      val = '$title $artist';
    }

    // Get.toNamed(ScreenNavigationSetup.searchResultScreen,
    //     id: ScreenNavigationSetup.id, arguments: val);
    // searchScreenController.addToHistryQueryList(val);

    // final isEmpty = searchScreenController
    //         .suggestionList.isEmpty ||
    //     searchScreenController.textInputController.text ==
    //         "";
    // final list = isEmpty
    //     ? searchScreenController.historyQuerylist.toList()
    //     : searchScreenController.suggestionList.toList();
    // return ListView(
    //     padding: const EdgeInsets.only(top: 5, bottom: 400),
    //     physics: const BouncingScrollPhysics(
    //         parent: AlwaysScrollableScrollPhysics()),
    //     children: searchScreenController.urlPasted.isTrue
    //         ? [
    //             InkWell(
    //               onTap: () {
    //                 searchScreenController.filterLinks(
    //                     Uri.parse(searchScreenController
    //                         .textInputController.text));
    //                 searchScreenController.reset();
    //               },
    //               child: Padding(
    //                 padding: const EdgeInsets.symmetric(
    //                     vertical: 10.0),
    //                 child: SizedBox(
    //                   width: double.maxFinite,
    //                   height: 60,
    //                   child: Center(
    //                       child: Text(
    //                     "urlSearchDes".tr,
    //                     style: Theme.of(context)
    //                         .textTheme
    //                         .titleMedium,
    //                   )),
    //                 ),
    //               ),
    //             )
    //           ]
    //         : list
    //             .map((item) => SearchItem(
    //                 queryString: item,
    //                 isHistoryString: isEmpty))
    //             .toList());
    // final audioHandler = Get.find<MyAudioHandler>();
    // final mediaItem = MediaItem(
    //   id: id ?? url,
    //   album: '',
    //   title: title ?? 'Received Song',
    //   extras: {'url': url},
    // );
    // await audioHandler.customAction('setSourceNPlay', {'mediaItem': mediaItem});
  }

  /// Clean up the listener when done (e.g., on app close).
  void dispose() {
    _connSub?.cancel();
    _connSub = null;
    _lastConnection = null;
  }
}
