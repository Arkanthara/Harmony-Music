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
              child: _ModeSelector(controller: controller),
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
                  if (running)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.connectedClients.value > 0
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 10,
                            color: controller.connectedClients.value > 0
                                ? Colors.green
                                : Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${controller.connectedClients.value} client(s) connected',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
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
    final client = controller.clientService;
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

            if (client != null)
              Obx(() {
                if (!client.isConnected.value) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${"connectedTo".tr} ${client.hostAddress ?? ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: controller.disconnectClient,
                        child: Text("disconnect".tr),
                      ),
                    ],
                  ),
                );
              }),

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
