import 'dart:async';
import 'package:get/get.dart';
import 'package:harmonymusic/models/playlist.dart';
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
  Future<void> _onReceived(String msg) async {
    final audioHandler = Get.find<MyAudioHandler>();
    final playerController = Get.find<PlayerController>();
    final searchResScrController =
        Get.isRegistered<SearchResultScreenController>()
            ? Get.find<SearchResultScreenController>()
            : null;

    // Split the message once
    final parts = msg.split('|');
    final command = parts[0];
    final arg1 = parts.length > 1 ? parts[1] : null;
    final arg2 = parts.length > 2 ? parts[2] : null;
    final arg3 = parts.length > 3 ? parts[3] : null;
    final arg4 = parts.length > 4 ? parts[4] : null;

    switch (command) {
      case 'PLAY_SONG':
        if (arg1 == null) return;
        final url = arg1;
        final id = (arg2?.isNotEmpty ?? false) ? arg2! : url;
        final title = (arg3?.isNotEmpty ?? false) ? arg3! : 'Received Song';
        final artist = (arg4?.isNotEmpty ?? false) ? arg4! : 'Received Artist';
        await _playReceivedSong(url, id, title, artist);
        break;

      case 'SEARCH':
        if (arg1 == null) return;
        final search = arg1;
        if (search.contains('https://')) {
          searchScreenController.filterLinks(Uri.parse(search));
          searchScreenController.reset();
        } else {
          Get.toNamed(
            ScreenNavigationSetup.searchResultScreen,
            id: ScreenNavigationSetup.id,
            arguments: search,
          );
          searchScreenController.addToHistryQueryList(search);

          if (GetPlatform.isDesktop) {
            searchScreenController.focusNode.unfocus();
          }
        }
        break;

      case 'TAB':
        if (arg1 == null) return;
        final tabIndex = int.tryParse(arg1);
        if (tabIndex != null) {
          searchResScrController?.tabController?.animateTo(tabIndex);
        }
        break;

      case 'BACK':
        Get.nestedKey(ScreenNavigationSetup.id)!.currentState!.pop();
        break;

      case 'PLAY':
        playerController.play();
        break;

      case 'PAUSE':
        playerController.pause();
        break;

      case 'NEXT':
        playerController.next();
        break;

      case 'PREV':
        playerController.prev();
        break;

      case 'SEEK':
        if (arg1 == null) return;
        final ms = int.tryParse(arg1) ?? 0;
        await audioHandler.seek(Duration(milliseconds: ms));
        break;

      case 'HOME':
        Get.toNamed(
          ScreenNavigationSetup.homeScreen,
          id: ScreenNavigationSetup.id,
        );
        break;

      case 'SEARCHSCREEN':
        Get.toNamed(
          ScreenNavigationSetup.searchScreen,
          id: ScreenNavigationSetup.id,
        );
        break;

      // case 'ALBUMSCREEN':
      //   if (arg1 == null) return;
      //   // Here you can fetch the Album if needed or pass dummy
      //   final album = Album(
      //     browseId: arg1,
      //     // fill minimal fields
      //   );
      //   Get.toNamed(
      //     ScreenNavigationSetup.albumScreen,
      //     id: ScreenNavigationSetup.id,
      //     arguments: (album, album.browseId),
      //   );
      //   break;

      // case 'PLAYLISTSCREEN':
      //   if (arg1 == null) return;
      //   // Similarly, create dummy Playlist or fetch
      //   final playlist = Playlist(
      //     browseId: arg1,
      //     // fill minimal fields
      //   );
      //   Get.toNamed(
      //     ScreenNavigationSetup.playlistScreen,
      //     id: ScreenNavigationSetup.id,
      //     arguments: [playlist, playlist.browseId],
      //   );
      //   break;

      // // You can add ARTISTSCREEN similarly
      // case 'ARTISTSCREEN':
      //   if (arg1 == null) return;
      //   final artist = Artist(
      //     browseId: arg1,
      //     // fill minimal fields
      //   );
      //   Get.toNamed(
      //     ScreenNavigationSetup.artistScreen,
      //     id: ScreenNavigationSetup.id,
      //     arguments: artist,
      //   );
      //   break;

      default:
        print('Unknown command: $command');
        break;
    }
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
