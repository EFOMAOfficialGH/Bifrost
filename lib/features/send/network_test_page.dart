import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/networking/bifrost_server.dart';

class NetworkTestPage extends StatefulWidget {
  const NetworkTestPage({super.key});

  @override
  State<NetworkTestPage> createState() => _NetworkTestPageState();
}

class _NetworkTestPageState extends State<NetworkTestPage> {
  BifrostServer? _server;
  String _message = 'The local receiver is stopped.';

  Future<void> _toggle() async {
    if (_server != null) {
      await _server!.close();
      setState(() {
        _server = null;
        _message = 'The local receiver is stopped.';
      });
      return;
    }

    try {
      final directory =
          await Directory.systemTemp.createTemp('bifrost-receive-');
      final server = BifrostServer(
        saveDirectory: directory,
        deviceName: 'Bifrost Test Receiver',
      );

      await server.start(address: InternetAddress.anyIPv4);

      setState(() {
        _server = server;
        _message =
            'Listening on ${server.address}. Files save to ${directory.path}.';
      });
    } catch (error) {
      setState(() {
        _message =
            'Could not start the receiver. Please check that Wi-Fi is on, '
            'then try again. Details: $error';
      });
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Networking test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestone 2 test receiver',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'This temporary screen starts a local receiver. '
              'A later screen will let you choose a file and send it '
              'from inside Bifrost.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_server == null ? Icons.play_arrow : Icons.stop),
              label: Text(
                _server == null ? 'Start receiver' : 'Stop receiver',
              ),
            ),
            const SizedBox(height: 18),
            SelectableText(_message),
          ],
        ),
      ),
    );
  }
}
