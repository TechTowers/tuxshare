import 'dart:io';
import 'dart:isolate';
import 'package:tuxshare/tuxshare.dart';

void backendMain(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final tuxshare = TuxShare(Platform.localHostname);
  await tuxshare.startListening();
  tuxshare.startDiscoveryLoop();
  tuxshare.discover();

  tuxshare.onPeerDiscovered = (peer) {
    sendPort.send({'type': 'peerDiscovered', 'data': peer.toJson()});
  };

  tuxshare.onPeerForget = (peer) {
    sendPort.send({'type': 'peerForget', 'data': peer.toJson()});
  };

  await for (var msg in receivePort) {
    if (msg is String && msg == "discover") {
      await tuxshare.discover();
    } else if (msg is List && msg[0] == "list") {
      final replyPort = msg[1] as SendPort;
      replyPort.send({
        'type': 'peerList',
        'data': tuxshare.peers.map((p) => p.toJson()).toList(),
      });
    } else if (msg == "exit") {
      tuxshare.close();
      break;
    }
  }
}
