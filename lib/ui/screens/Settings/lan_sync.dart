import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/services/lan_connection_service.dart';
import 'package:harmonymusic/services/lan_sync_service.dart';

class LanSyncSettingsSection extends StatefulWidget {
  @override
  _LanSyncSettingsSectionState createState() => _LanSyncSettingsSectionState();
}

class _LanSyncSettingsSectionState extends State<LanSyncSettingsSection> {
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController =
      TextEditingController(text: "4040");
  bool isHost = false;
  String status = 'Not connected';
  LanConnectionService? connectionService;
  LanSyncService? syncService;

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    connectionService?.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    setState(() {
      status = "Connecting...";
    });

    connectionService?.dispose();
    connectionService = LanConnectionService();
    syncService = LanSyncService(connectionService!);

    try {
      if (isHost) {
        final port = int.tryParse(portController.text) ?? 4040;
        final listeningPort =
            await connectionService!.startAsServer(port: port);
        // Get local IP address for user to share
        final interfaces = await NetworkInterface.list(
            type: InternetAddressType.IPv4, includeLinkLocal: false);
        final ip = interfaces
            .firstWhere((iface) => iface.addresses.isNotEmpty)
            .addresses
            .first
            .address;
        setState(() {
          status = "Hosting on $ip:$listeningPort\nWaiting for client...";
        });
      } else {
        final ip = ipController.text.trim();
        final port = int.tryParse(portController.text) ?? 4040;
        await connectionService!.connectToServer(ip, port);
        setState(() {
          status = "Connected to $ip:$port";
        });
      }
      // Listen for connection state
      connectionService!.onReceived.listen((msg) {
        setState(() {
          status = "Connected!\nLast received: $msg";
        });
      });
    } catch (e) {
      setState(() {
        status = "Connection failed: $e";
      });
    }
  }

  void disconnect() {
    connectionService?.dispose();
    setState(() {
      status = "Not connected";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("LAN Sync", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text("Host"),
                    leading: Radio<bool>(
                      value: true,
                      groupValue: isHost,
                      onChanged: (val) {
                        setState(() {
                          isHost = true;
                        });
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text("Client"),
                    leading: Radio<bool>(
                      value: false,
                      groupValue: isHost,
                      onChanged: (val) {
                        setState(() {
                          isHost = false;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isHost)
              TextField(
                controller: ipController,
                decoration: const InputDecoration(labelText: "Host IP Address"),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: "Port"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: connect,
                  child: Text(isHost ? "Start Hosting" : "Connect"),
                ),
                const SizedBox(width: 16),
                if (status != "Not connected")
                  ElevatedButton(
                    onPressed: disconnect,
                    child: const Text("Disconnect"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              status,
              style: TextStyle(
                  color: status.contains("failed") ? Colors.red : Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
