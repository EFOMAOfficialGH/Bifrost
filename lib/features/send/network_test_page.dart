import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/networking/bifrost_client.dart';
import '../../core/networking/bifrost_server.dart';

class NetworkTestPage extends StatefulWidget {
  const NetworkTestPage({super.key});
  @override
  State<NetworkTestPage> createState() => _NetworkTestPageState();
}

class _NetworkTestPageState extends State<NetworkTestPage> {
  BifrostServer? _server;
  String _message = 'The local receiver is stopped.';
  bool _testing = false;

  Future<void> _toggle() async {
    if (_server != null) {
      await _server!.close();
      setState(() { _server = null; _message = 'The local receiver is stopped.'; });
      return;
    }
    try {
      final directory = await Directory.systemTemp.createTemp('bifrost-receive-');
      final server = BifrostServer(saveDirectory: directory, deviceName: 'Bifrost Test Receiver');
      await server.start(address: InternetAddress.anyIPv4);
      setState(() { _server = server; _message = 'Listening on ${server.address}. Files save to ${directory.path}.'; });
    } catch (error) {
      setState(() { _message = 'Could not start the receiver. Please check that Wi-Fi is on, then try again. Details: $error'; });
    }
  }

  Future<void> _runSelfTest() async {
    setState(() { _testing = true; _message = 'Running a local send and checksum test…'; });
    final root = await Directory.systemTemp.createTemp('bifrost-self-test-');
    final source = File('${root.path}/bifrost-test.txt')..writeAsStringSync('Bifrost local test passed');
    final destination = Directory('${root.path}/received');
    final server = BifrostServer(saveDirectory: destination, deviceName: 'Bifrost Self Test');
    final client = BifrostClient();
    try {
      await server.start();
      await client.sendFile(server: Uri.parse(server.address), file: source, remoteName: 'self-test.txt');
      final files = await destination.list().toList();
      if (mounted) setState(() { _message = files.isNotEmpty ? 'Self-test passed: one file was streamed and checksum verified.' : 'Self-test failed: no received file was found.'; });
    } catch (error) {
      if (mounted) setState(() { _message = 'Self-test failed: $error'; });
    } finally {
      client.close();
      await server.close();
      await root.delete(recursive: true);
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  void dispose() { _server?.close(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Networking test')),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Milestone 2 test receiver', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('This temporary screen starts a local receiver. A later screen will let you choose a file and send it from inside Bifrost.'),
      const SizedBox(height: 24),
      FilledButton.icon(onPressed: _testing ? null : _toggle, icon: Icon(_server == null ? Icons.play_arrow : Icons.stop), label: Text(_server == null ? 'Start receiver' : 'Stop receiver')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _testing ? null : _runSelfTest, icon: const Icon(Icons.science_outlined), label: const Text('Run one-device self-test')),
      const SizedBox(height: 18),
      SelectableText(_message),
    ])),
  );
}
