import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/networking/offer_broker.dart';

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
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final offer = incoming.offer;
      final accepted = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
        title: const Text('Incoming transfer'),
        content: Text('${offer.files.length} file${offer.files.length == 1 ? '' : 's'} • ${_bytes(offer.totalBytes)}\n\n${offer.files.map((file) => file.name).join('\n')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Decline')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Accept')),
        ],
      )) ?? false;
      BifrostOfferBroker.instance.decide(offer.transferId, accepted);
      _dialogOpen = false;
    });
  }

  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.child;
}

String _bytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
