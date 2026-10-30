import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import '../../core/localization/app_localizations.dart';
import '../../core/localization/localized_text.dart';
import 'app_transfer_service.dart';

/// Lets the user select several installed apps and adds ready artifacts to the
/// ordinary Nearby queue. Single-APK apps are passed through without archiving.
class AppTransferPicker extends StatefulWidget {
  const AppTransferPicker({super.key, required this.onAppsReady, this.service});

  final Future<void> Function(List<AppTransferArtifact> artifacts) onAppsReady;
  final AppTransferService? service;

  @override
  State<AppTransferPicker> createState() => _AppTransferPickerState();
}

enum _AppFilter { all, singleApk, split }

class _AppTransferPickerState extends State<AppTransferPicker> {
  late final AppTransferService _service =
      widget.service ?? AppTransferService();
  List<TransferableApp> _apps = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _gridView = true;
  bool _includeObb = false;
  bool _preparing = false;
  String? _error;
  String _query = '';
  _AppFilter _filter = _AppFilter.all;
  int _preparingIndex = 0;
  int _preparingTotal = 0;
  String? _preparingName;
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
      if (mounted) {
        setState(() {
          _apps = apps;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  List<TransferableApp> get _filteredApps {
    final query = _query.trim().toLowerCase();
    return _apps
        .where((app) {
          final matchesQuery =
              query.isEmpty ||
              '${app.name} ${app.packageName} ${app.versionName}'
                  .toLowerCase()
                  .contains(query);
          final matchesFilter = switch (_filter) {
            _AppFilter.all => true,
            _AppFilter.singleApk => app.apkPaths.length == 1,
            _AppFilter.split => app.apkPaths.length > 1,
          };
          return matchesQuery && matchesFilter;
        })
        .toList(growable: false);
  }

  Future<void> _toggleObb(bool include) async {
    if (include && !await _service.hasAllFilesAccess()) {
      await _service.requestAllFilesAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Grant All files access, return to Bifrost, then enable Include optional OBB data.',
            ),
          ),
        );
      }
      return;
    }
    if (mounted) setState(() => _includeObb = include);
  }

  void _toggleSelected(TransferableApp app) {
    setState(() {
      if (!_selected.add(app.packageName)) _selected.remove(app.packageName);
    });
  }

  void _toggleAllShown() {
    final shown = _filteredApps.map((app) => app.packageName).toSet();
    final allSelected = shown.isNotEmpty && shown.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(shown);
      } else {
        _selected.addAll(shown);
      }
    });
  }

  Future<void> _sendSelected() async {
    final chosen = _apps
        .where((app) => _selected.contains(app.packageName))
        .toList(growable: false);
    if (chosen.isEmpty || _preparing) return;

    final artifacts = <AppTransferArtifact>[];
    setState(() {
      _preparing = true;
      _preparingIndex = 0;
      _preparingTotal = chosen.length;
      _preparingName = null;
      _progress = 0;
    });
    try {
      for (var index = 0; index < chosen.length; index++) {
        final app = chosen[index];
        if (mounted) {
          setState(() {
            _preparingIndex = index + 1;
            _preparingName = app.name;
            _progress = 0;
          });
        }
        final artifact = app.apkPaths.length == 1 && !_includeObb
            ? AppTransferArtifact(
                file: File(app.apkPaths.single),
                remoteName: '${_safeFileName(app.name)}.apk',
                isTemporary: false,
                isArchive: false,
              )
            : await _service.prepareAppTransfer(
                app,
                includeObb: _includeObb,
                onProgress: (value) {
                  if (mounted) setState(() => _progress = value);
                },
              );
        artifacts.add(artifact);
      }
      await widget.onAppsReady(List.unmodifiable(artifacts));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      for (final artifact in artifacts.where((item) => item.isTemporary)) {
        await _service.deleteTemporaryExport(artifact.file.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare app transfer: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _preparing = false;
          _preparingName = null;
        });
      }
    }
  }

  Widget _appIcon(TransferableApp app, {double size = 48}) {
    final icon = app.iconPng;
    if (icon == null) return Icon(Icons.android, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        icon,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(Icons.android, size: size),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _safeFileName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    return safe.isEmpty ? 'App' : safe;
  }

  Widget _buildListTile(TransferableApp app) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: CheckboxListTile(
      value: _selected.contains(app.packageName),
      onChanged: _preparing ? null : (_) => _toggleSelected(app),
      secondary: _appIcon(app, size: 42),
      title: Text(
        app.name,
        localized: false,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            app.packageName,
            localized: false,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            AppLocalizations.translate(
              context,
              'Version ${app.versionName} (${app.versionCode}) · APK size ${_size(app.apkSizeBytes)}',
            ),
          ),
          Text(
            app.apkPaths.length == 1
                ? 'Single APK'
                : '${app.apkPaths.length} APK splits',
          ),
        ],
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      isThreeLine: true,
    ),
  );

  Widget _buildGridCard(TransferableApp app) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _preparing ? null : () => _toggleSelected(app),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _appIcon(app, size: 44),
                const Spacer(),
                Checkbox(
                  value: _selected.contains(app.packageName),
                  onChanged: _preparing ? null : (_) => _toggleSelected(app),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              app.name,
              localized: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              app.packageName,
              localized: false,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              '${AppLocalizations.translate(context, app.apkPaths.length == 1 ? 'Single APK' : '${app.apkPaths.length} APK splits')} · ${_size(app.apkSizeBytes)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Version ${app.versionName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredApps;
    final allShownSelected =
        filtered.isNotEmpty &&
        filtered.every((app) => _selected.contains(app.packageName));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer apps'),
        actions: [
          IconButton(
            tooltip: allShownSelected ? 'Clear selection' : 'Select all shown',
            onPressed: _preparing || filtered.isEmpty ? null : _toggleAllShown,
            icon: Icon(allShownSelected ? Icons.deselect : Icons.select_all),
          ),
          IconButton(
            tooltip: _gridView ? 'Switch to list view' : 'Switch to grid view',
            onPressed: _preparing
                ? null
                : () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'App Transfer is intended for personal use with apps you own. Only APKs and optional OBB files are included; app data is never copied.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search installed apps',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All apps', _AppFilter.all),
                  _filterChip('Single APK', _AppFilter.singleApk),
                  _filterChip('Split apps', _AppFilter.split),
                ],
              ),
            ),
          ),
          SwitchListTile.adaptive(
            value: _includeObb,
            onChanged: _preparing ? null : _toggleObb,
            title: const Text('Include optional OBB data'),
            subtitle: const Text(
              'Only selected apps are scanned. APK size is shown without OBB data.',
            ),
            secondary: const Icon(Icons.folder_special_outlined),
            dense: true,
          ),
          if (_preparing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preparing $_preparingIndex of $_preparingTotal: ${_preparingName ?? ''}',
                  ),
                  const SizedBox(height: 6),
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
                ? const Center(child: Text('No apps match the current search.'))
                : _gridView
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 980
                          ? 4
                          : constraints.maxWidth >= 620
                          ? 3
                          : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: 0.92,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildGridCard(filtered[index]),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildListTile(filtered[index]),
                  ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selected.length} selected',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _preparing ? null : _sendSelected,
                      icon: const Icon(Icons.send),
                      label: Text('Send ${_selected.length} selected'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _AppFilter value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: _preparing ? null : (_) => setState(() => _filter = value),
    ),
  );
}
