import 'dart:io';
import 'dart:isolate';

import 'package:tuxshare/peer_info.dart';
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

  tuxshare.onRequest = (request) {
    sendPort.send({'type': 'request', 'data': request});
  };

  tuxshare.onRequestDecline = (request) {
    sendPort.send({'type': 'decline', 'data': request});
  };

  await for (var msg in receivePort) {
    if (msg is Map<String, dynamic>) {
      if (msg["type"] == "discover") {
        await tuxshare.discover();
      } else if (msg["type"] == "exit") {
        tuxshare.close();
        break;
      } else if (msg["type"] == "send") {
        tuxshare.sendFile(
          PeerInfo.fromJson(msg["data"]["peer"]),
          msg["data"]["file"],
        );
      } else if (msg["type"] == "accept") {
        tuxshare.acceptFile(
          msg["data"]["hash"],
          PeerInfo.fromJson(msg["data"]["peer"]),
          msg["data"]["destination"],
        );
      } else if (msg["type"] == "decline") {
        tuxshare.declineFile(
          msg["data"]["hash"],
          PeerInfo.fromJson(msg["data"]["peer"]),
        );
      }
    }
  }
}
