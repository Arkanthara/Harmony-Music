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
  final ipController = TextEditingController();
  final portController = TextEditingController(text: "4040");
  List<String> _hostIps = [];

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Restore role and connection state if present (persists across navigation)
    final lanSync = Get.find<LanSyncController>();
    if (lanSync.role.value == LanRole.host) {
      isHost = true;
      _updateHostIps();
    } else if (lanSync.role.value == LanRole.client) {
      isHost = false;
      ipController.text = lanSync.conn?.socket?.remoteAddress.address ?? "";
      portController.text =
          lanSync.conn?.socket?.remotePort.toString() ?? "4040";
    }
  }

  Future<void> _updateHostIps() async {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLinkLocal: false);
    _hostIps = interfaces
        .expand((iface) => iface.addresses)
        .map((addr) => addr.address)
        .where((ip) => !ip.startsWith('127.'))
        .toList();
    if (mounted) setState(() {});
  }

  Future<void> connect() async {
    final lanSync = Get.find<LanSyncController>();
    lanSync.disconnect();

    final conn = LanConnectionService();
    try {
      if (isHost) {
        // final port = int.tryParse(portController.text) ?? 4040;
        // final listeningPort = await conn.startAsServer(port: port);
        await _updateHostIps();
        lanSync.setHost(conn);
      } else {
        final ip = ipController.text.trim();
        final port = int.tryParse(portController.text) ?? 4040;
        await conn.connectToServer(ip, port);
        lanSync.setClient(conn);
      }
    } catch (e) {
      lanSync.disconnect();
      Get.snackbar("LAN Sync", "Connection failed: $e",
          backgroundColor: Colors.red[200]);
    }
  }

  void disconnect() {
    final lanSync = Get.find<LanSyncController>();
    lanSync.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<LanSyncController>(
      builder: (lanSync) {
        String status;
        if (lanSync.connected.value) {
          if (lanSync.isHost) {
            final clientIp = lanSync.conn?.socket?.remoteAddress.address;
            if (clientIp != null) {
              status = "Host: Client connected from $clientIp";
            } else {
              status =
                  "Hosting on:\n${_hostIps.map((ip) => "$ip:${lanSync.conn?.serverSocket?.port ?? portController.text}").join('\n')}\nWaiting for client...";
            }
          } else if (lanSync.isClient) {
            final hostIp = lanSync.conn?.socket?.remoteAddress.address ??
                ipController.text;
            final hostPort = lanSync.conn?.socket?.remotePort.toString() ??
                portController.text;
            status = "Client: Connected to $hostIp:$hostPort";
          } else {
            status = "Connected (unknown role)";
          }
        } else {
          status = "Not connected";
        }

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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Disconnect"),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              status,
              style: TextStyle(
                  color: status.contains("failed")
                      ? Colors.red
                      : status.contains("Waiting")
                          ? Colors.orange
                          : Colors.green),
            ),
          ],
        );
      },
    );
  }
}
