import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import '../../core/localization/app_localizations.dart';
import '../../core/localization/localized_text.dart';
import 'app_transfer_service.dart';

/// Standalone selector intended to be embedded/navigated to by Nearby.
/// [onXapkReady] receives a temporary .xapk file for the existing Bifrost
/// sender; no separate networking path is started here.
class AppTransferPicker extends StatefulWidget {
  const AppTransferPicker({super.key, required this.onXapkReady, this.service});

  final Future<void> Function(File xapk) onXapkReady;
  final AppTransferService? service;

  @override
  State<AppTransferPicker> createState() => _AppTransferPickerState();
}

class _AppTransferPickerState extends State<AppTransferPicker> {
  late final AppTransferService _service =
      widget.service ?? AppTransferService();
  List<TransferableApp> _apps = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _packaging;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await _service.listInstalledUserApps();
      if (mounted)
        setState(() {
          _apps = apps;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  Future<void> _select(TransferableApp app) async {
    if (_packaging != null) return;
    if ((app.hasObb || app.obbAccessRequired) &&
        !await _service.hasAllFilesAccess()) {
      await _service.requestAllFilesAccess();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Grant All files access to check for optional OBB data, then select the app again.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _packaging = app.packageName;
      _progress = 0;
    });
    try {
      final file = await _service.createXapk(
        app,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      await widget.onXapkReady(file);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare ${app.name}: $error')),
        );
    } finally {
      if (mounted) setState(() => _packaging = null);
    }
  }

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _apps
        .where(
          (app) => '${app.name} ${app.packageName}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer an app')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'App Transfer is intended for personal use with apps you own. Only APKs and optional OBB files are included; app data is never copied.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search installed apps',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (_packaging != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preparing ${_apps.firstWhere((e) => e.packageName == _packaging).name}…',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? const Center(
                    child: Text('No installed user apps match this search.'),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final app = filtered[index];
                      return ListTile(
                        leading: app.iconPng == null
                            ? const Icon(Icons.android)
                            : Image.memory(
                                app.iconPng!,
                                width: 40,
                                height: 40,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.android),
                              ),
                        title: Text(app.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.packageName,
                              localized: false,
                              textDirection: TextDirection.ltr,
                            ),
                            Text(
                              AppLocalizations.translate(
                                context,
                                'Version ${app.versionName} (${app.versionCode}) · Size ${_size(app.sizeBytes)}',
                              ),
                            ),
                            if (app.hasObb)
                              const Text('OBB files included')
                            else if (app.obbAccessRequired)
                              const Text('OBB check requires All files access'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.send),
                        onTap: _packaging == null ? () => _select(app) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
