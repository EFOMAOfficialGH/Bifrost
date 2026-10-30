import 'dart:io';

import 'package:flutter/material.dart' hide Text;

import '../../core/localization/app_localizations.dart';
import '../../core/localization/localized_text.dart';

class TransferQueueDialog extends StatefulWidget {
  const TransferQueueDialog({
    required this.files,
    required this.statuses,
    required this.sending,
    super.key,
  });

  final List<File> files;
  final Map<String, String> statuses;
  final bool sending;

  @override
  State<TransferQueueDialog> createState() => _TransferQueueDialogState();
}

class _TransferQueueDialogState extends State<TransferQueueDialog> {
  late List<File> _files;

  @override
  void initState() {
    super.initState();
    _files = List<File>.of(widget.files);
  }

  void _reorder(int oldIndex, int newIndex) {
    if (widget.sending || oldIndex == newIndex) return;
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final file = _files.removeAt(oldIndex);
      _files.insert(newIndex, file);
    });
  }

  void _finish() => Navigator.of(context).pop(List<File>.unmodifiable(_files));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Transfer queue'),
      content: SizedBox(
        width: size.width * 0.78,
        height: size.height * 0.55,
        child: _files.isEmpty
            ? const Center(child: Text('No files queued.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Drag the handle to change order.'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: _files.length,
                      onReorder: widget.sending ? (_, __) {} : _reorder,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final status = widget.statuses[file.path] ?? 'Queued';
                        return ListTile(
                          key: ValueKey(file.path),
                          dense: true,
                          leading: widget.sending
                              ? const Icon(Icons.drag_handle)
                              : ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle),
                                ),
                          title: Text(
                            file.uri.pathSegments.isEmpty
                                ? file.path
                                : file.uri.pathSegments.last,
                            localized: false,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_fileSize(file)} • ${AppLocalizations.translateCurrent(status)}',
                          ),
                          trailing: IconButton(
                            tooltip: AppLocalizations.translateCurrent('Remove'),
                            onPressed: widget.sending
                                ? null
                                : () => setState(() => _files.removeAt(index)),
                            icon: const Icon(Icons.close),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: widget.sending || _files.isEmpty
              ? null
              : () => setState(_files.clear),
          child: const Text('Clear queued files'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _finish, child: const Text('Done')),
      ],
    );
  }

  String _fileSize(File file) {
    try {
      if (!file.existsSync()) return AppLocalizations.translateCurrent('Unavailable');
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } on FileSystemException {
      return AppLocalizations.translateCurrent('Unavailable');
    }
  }
}
