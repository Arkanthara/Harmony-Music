import 'dart:io';

import 'package:flutter/material.dart';
import 'package:harmonymusic/services/lan_connection_service.dart';
import 'package:harmonymusic/services/lan_sync_service.dart';

class LanSyncSettingsUI extends StatefulWidget {
  const LanSyncSettingsUI({super.key});

  @override
  State<LanSyncSettingsUI> createState() => LanSyncSettingsUIState();
}

class LanSyncSettingsUIState extends State<LanSyncSettingsUI> {
  bool isHost = false;
  String status = 'Not connected';
  final ipController = TextEditingController();
  final portController = TextEditingController(text: "4040");
  LanConnectionService? _conn;
  // LanSyncService? _sync;

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    _conn?.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    setState(() {
      status = "Connecting...";
    });
    _conn?.dispose();
    _conn = LanConnectionService();
    // _sync = LanSyncService(_conn!);
    try {
      if (isHost) {
        final port = int.tryParse(portController.text) ?? 4040;
        final listeningPort = await _conn!.startAsServer(port: port);
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
        await _conn!.connectToServer(ip, port);
        setState(() {
          status = "Connected to $ip:$port";
        });
      }
      _conn!.onReceived.listen((msg) {
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
    _conn?.dispose();
    setState(() {
      status = "Not connected";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text("Host"),
                leading: Radio<bool>(
                  value: true,
                  groupValue: isHost,
                  onChanged: (val) => setState(() => isHost = true),
                ),
              ),
            ),
            Expanded(
              child: ListTile(
                title: const Text("Client"),
                leading: Radio<bool>(
                  value: false,
                  groupValue: isHost,
                  onChanged: (val) => setState(() => isHost = false),
                ),
              ),
            ),
          ],
        ),
        if (!isHost)
          TextField(
            controller: ipController,
            decoration: const InputDecoration(labelText: "Host IP Address"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Disconnect"),
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
    );
  }
}
