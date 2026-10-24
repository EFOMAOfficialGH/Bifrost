import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../../core/localization/localized_text.dart';

import '../../core/networking/offer_broker.dart';
import '../../core/notifications/transfer_notifications.dart';
import '../../core/storage/app_storage.dart';

class IncomingOfferListener extends StatefulWidget {
  const IncomingOfferListener({required this.child, super.key});
  final Widget child;
  @override
  State<IncomingOfferListener> createState() => _IncomingOfferListenerState();
}

class _IncomingOfferListenerState extends State<IncomingOfferListener> {
  StreamSubscription<IncomingOffer>? _subscription;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _subscription = BifrostOfferBroker.instance.offers.listen(_showOffer);
  }

  void _showOffer(IncomingOffer incoming) {
    if (!mounted || _dialogOpen) return;
    TransferNotifications.instance.incoming(id: incoming.offer.transferId.hashCode, title: 'Incoming transfer', body: '${incoming.offer.files.length} file${incoming.offer.files.length == 1 ? '' : 's'} is ready for approval');
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final offer = incoming.offer;
      var trust = false;
      final decision = await showDialog<(bool, bool)>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Incoming transfer'),
                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${offer.files.length} file${offer.files.length == 1 ? '' : 's'} • ${_bytes(offer.totalBytes)}\n\n${offer.files.map((file) => file.name).join('\n')}'),
                  if (incoming.senderDeviceId != null) CheckboxListTile(contentPadding: EdgeInsets.zero, value: trust, onChanged: (value) => setDialogState(() => trust = value ?? false), title: const Text('Trust this device'), subtitle: const Text('Automatically accept future transfers from it.')),
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, (false, false)), child: const Text('Decline')),
                  FilledButton(onPressed: () => Navigator.pop(dialogContext, (true, trust)), child: const Text('Accept')),
                ],
              ),
            ),
          ) ??
          (false, false);
      if (decision.$2 && incoming.senderDeviceId != null) await AppStorage.instance.setTrusted(incoming.senderDeviceId!, true, name: incoming.senderDeviceName ?? 'Trusted device');
      BifrostOfferBroker.instance.decide(offer.transferId, decision.$1);
      if (decision.$1 && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer started')));
      _dialogOpen = false;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _bytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
