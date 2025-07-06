import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harmonymusic/services/lan_connection_service.dart';
import 'package:harmonymusic/services/lan_sync_controller.dart';

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
  List<String> _hostIps = [];

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    // Not needed: connection cleanup now handled in controller
    super.dispose();
  }

  Future<void> connect() async {
    setState(() {
      status = "Connecting...";
    });

    final lanSync = Get.find<LanSyncController>();
    lanSync.disconnect(); // Clean up any previous connection

    final conn = LanConnectionService();
    try {
      if (isHost) {
        final port = int.tryParse(portController.text) ?? 4040;
        final listeningPort = await conn.startAsServer(port: port);
        final interfaces = await NetworkInterface.list(
            type: InternetAddressType.IPv4, includeLinkLocal: false);
        _hostIps = interfaces
            .expand((iface) => iface.addresses)
            .map((addr) => addr.address)
            .where((ip) => !ip.startsWith('127.')) // filter out localhost
            .toList();
        lanSync.setHost(conn);
        setState(() {
          status =
              "Hosting on:\n${_hostIps.map((ip) => "$ip:$listeningPort").join('\n')}\nWaiting for client...";
        });
      } else {
        final ip = ipController.text.trim();
        final port = int.tryParse(portController.text) ?? 4040;
        await conn.connectToServer(ip, port);
        lanSync.setClient(conn);
        setState(() {
          status = "Connected to $ip:$port";
        });
      }

      conn.onReceived.listen((msg) {
        setState(() {
          status = "Connected!\nLast received: $msg";
        });
      });
    } catch (e) {
      lanSync.disconnect();
      setState(() {
        status = "Connection failed: $e";
      });
    }
  }

  void disconnect() {
    final lanSync = Get.find<LanSyncController>();
    lanSync.disconnect();
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
        if (isHost && _hostIps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Your Host IPs:\n${_hostIps.join('\n')}",
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
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
