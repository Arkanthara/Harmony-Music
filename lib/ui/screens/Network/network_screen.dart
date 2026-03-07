import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '/ui/screens/Network/network_controller.dart';
import '/ui/widgets/snackbar.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NetworkController>();

    return Scaffold(
      appBar: AppBar(
        title: Text("networkPlay".tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text("networkPlayDes".tr,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Expanded(
              child: Obx(() {
                final mode = controller.networkMode.value;
                if (mode == NetworkMode.client &&
                    controller.clientService != null &&
                    controller.clientService!.isConnected.value) {
                  return _ClientRemote(controller: controller);
                }
                return _ModeSelector(controller: controller);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Mode Selector (Host / Client) ──────────────────────

class _ModeSelector extends StatelessWidget {
  final NetworkController controller;
  const _ModeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 200),
      children: [
        _HostSection(controller: controller),
        const SizedBox(height: 24),
        _ClientSection(controller: controller),
      ],
    );
  }
}

// ─────────────────────────── Host Section ────────────────────────────────────

class _HostSection extends StatelessWidget {
  final NetworkController controller;
  const _HostSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_tethering, size: 28),
                const SizedBox(width: 12),
                Text("hostMode".tr,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text("hostModeDes".tr,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Obx(() {
              final running = controller.isHostRunning.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (running && controller.hostIp.value != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text("${"ipAddress".tr}:",
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          SelectableText(
                            '${controller.hostIp.value}:8899',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(running ? Icons.stop : Icons.play_arrow),
                      label:
                          Text(running ? "stopHost".tr : "startHost".tr),
                      onPressed: () async {
                        if (running) {
                          await controller.stopHost();
                        } else {
                          await controller.startHost();
                        }
                      },
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Client Section ─────────────────────────────────

class _ClientSection extends StatefulWidget {
  final NetworkController controller;
  const _ClientSection({required this.controller});

  @override
  State<_ClientSection> createState() => _ClientSectionState();
}

class _ClientSectionState extends State<_ClientSection> {
  final _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, size: 28),
                const SizedBox(width: 12),
                Text("clientMode".tr,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text("clientModeDes".tr,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),

            // Manual IP input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      hintText: "enterHostIp".tr,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _connect(context, _ipController.text.trim()),
                  child: Text("connect".tr),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scan button
            Obx(() => SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: controller.isScanning.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.radar),
                    label: Text(controller.isScanning.value
                        ? "scanning".tr
                        : "scanNetwork".tr),
                    onPressed: controller.isScanning.value
                        ? null
                        : () => controller.scanForHosts(),
                  ),
                )),

            // Discovered hosts
            Obx(() {
              if (controller.discoveredHosts.isEmpty &&
                  !controller.isScanning.value) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text("discoveredHosts".tr,
                      style: Theme.of(context).textTheme.titleSmall),
                  ...controller.discoveredHosts.map((ip) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.computer, size: 20),
                        title: Text(ip),
                        trailing: FilledButton.tonal(
                          onPressed: () => _connect(context, ip),
                          child: Text("connect".tr),
                        ),
                      )),
                ],
              );
            }),

            // Saved hosts
            Obx(() {
              final saved = controller.savedHosts;
              if (saved.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text("savedHosts".tr,
                      style: Theme.of(context).textTheme.titleSmall),
                  ...saved.map((ip) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmark, size: 20),
                        title: Text(ip),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _connect(context, ip),
                              child: Text("connect".tr),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () =>
                                  controller.removeSavedHost(ip),
                            ),
                          ],
                        ),
                      )),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _connect(BuildContext context, String ip) async {
    if (ip.isEmpty) return;
    try {
      await widget.controller.connectToHost(ip);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            snackbar(context, "${"connectionFailed".tr}: $e",
                size: SanckBarSize.BIG));
      }
    }
  }
}

// ──────────────────────── Client Remote Control ─────────────────────────────

class _ClientRemote extends StatefulWidget {
  final NetworkController controller;
  const _ClientRemote({required this.controller});

  @override
  State<_ClientRemote> createState() => _ClientRemoteState();
}

class _ClientRemoteState extends State<_ClientRemote> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.controller.clientService!;
    return Column(
      children: [
        // Connection header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withAlpha(60),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, size: 18),
              const SizedBox(width: 8),
              Text(
                "${"connectedTo".tr} ${client.hostAddress ?? ''}",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => widget.controller.disconnectClient(),
                child: Text("disconnect".tr),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Now Playing
        Obx(() => _NowPlayingCard(client: client)),

        const SizedBox(height: 16),

        // Search bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "searchMusic".tr,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onSubmitted: (q) {
                  if (q.trim().isNotEmpty) {
                    client.remoteSearch(q.trim());
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Obx(() => client.isSearching.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      final q = _searchController.text.trim();
                      if (q.isNotEmpty) client.remoteSearch(q);
                    },
                  )),
          ],
        ),
        const SizedBox(height: 8),

        // Search results
        Expanded(
          child: Obx(() {
            final results = client.searchResults;
            if (results.isEmpty) {
              return Center(
                child: Text("searchToPlay".tr,
                    style: Theme.of(context).textTheme.bodyMedium),
              );
            }
            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: results.length,
              padding: const EdgeInsets.only(bottom: 200),
              itemBuilder: (context, index) {
                final song = results[index];
                final title = song['title'] ?? '';
                final artists = (song['artists'] as List?)
                        ?.map((a) => a['name'])
                        .join(', ') ??
                    '';
                final thumb = (song['thumbnails'] as List?)?.isNotEmpty == true
                    ? song['thumbnails'][0]['url']
                    : null;

                return ListTile(
                  leading: thumb != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: thumb,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.music_note),
                  title: Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(artists,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => client.remotePlaySong(song),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

// ──────────────────────── Now Playing Card ───────────────────────────────────

class _NowPlayingCard extends StatelessWidget {
  final dynamic client;
  const _NowPlayingCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final song = client.currentSong.value;
    if (song == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: Text("nothingPlaying".tr,
                  style: Theme.of(context).textTheme.bodyLarge)),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Song info
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: song.artUri.toString(),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.music_note, size: 48),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song.artist != null)
                        Text(
                          song.artist!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ProgressBar(
              progress: Duration(milliseconds: client.position.value),
              buffered: Duration(milliseconds: client.buffered.value),
              total: Duration(milliseconds: client.duration.value),
              onSeek: (d) => client.remoteSeek(d.inMilliseconds),
              barHeight: 3,
              thumbRadius: 6,
              timeLabelTextStyle: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),

            // Transport controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 36,
                  onPressed: client.remotePrev,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(
                    client.isPlaying.value
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  iconSize: 56,
                  onPressed: client.isPlaying.value
                      ? client.remotePause
                      : client.remotePlay,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 36,
                  onPressed: client.remoteNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
