import 'dart:async';

import 'protocol.dart';

class IncomingOffer {
  const IncomingOffer(this.offer, this.senderDeviceId);
  final BifrostTransferOffer offer;
  final String? senderDeviceId;
}

class BifrostOfferBroker {
  BifrostOfferBroker._();
  static final instance = BifrostOfferBroker._();

  final _events = StreamController<IncomingOffer>.broadcast();
  final _pending = <String, Completer<bool>>{};
  Stream<IncomingOffer> get offers => _events.stream;

  Future<bool> request(BifrostTransferOffer offer, [String? senderDeviceId]) {
    final completer = Completer<bool>();
    _pending[offer.transferId] = completer;
    _events.add(IncomingOffer(offer, senderDeviceId));
    return completer.future.timeout(const Duration(minutes: 2), onTimeout: () => false).whenComplete(() => _pending.remove(offer.transferId));
  }

  void decide(String transferId, bool accepted) => _pending.remove(transferId)?.complete(accepted);
}
