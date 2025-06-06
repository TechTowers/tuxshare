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

  tuxshare.onPeerDisappear = (peer) {
    sendPort.send({'type': 'peerDisappear', 'data': peer.toJson()});
  };

  tuxshare.onOfferFail = (request) {
    final serializedRequest = {
      ...request,
      "peer": request["peer"].toJson(), // manually serialize PeerInfo
    };

    sendPort.send({"type": "sendOfferFail", "data": serializedRequest});
  };

  tuxshare.onRequest = (request) {
    sendPort.send({'type': 'request', 'data': request});
  };

  tuxshare.onOfferReject = (request) {
    sendPort.send({'type': 'reject', 'data': request});
  };

  tuxshare.onFileReceived = (filePath) {
    sendPort.send({'type': 'fileReceived', 'data': filePath});
  };

  tuxshare.onSendingFileError = (peer, file, error) {
    sendPort.send({
      'type': 'sendingFileError',
      'data': {'peer': peer.toJson(), 'file': file, 'error': error.toString()},
    });
  };

  tuxshare.onReceivingFileError = (file, error) {
    sendPort.send({
      'type': 'receivingFileError',
      'data': {'file': file, 'error': error.toString()},
    });
  };

  await for (var msg in receivePort) {
    if (msg is Map<String, dynamic>) {
      if (msg["type"] == "discover") {
        await tuxshare.discover();
      } else if (msg["type"] == "exit") {
        tuxshare.close();
        break;
      } else if (msg["type"] == "send") {
        tuxshare.sendOffer(
          PeerInfo.fromJson(msg["data"]["peer"]),
          msg["data"]["file"],
        );
      } else if (msg["type"] == "accept") {
        tuxshare.acceptFile(
          msg["data"]["requestID"],
          msg["data"]["hash"],
          PeerInfo.fromJson(msg["data"]["peer"]),
          msg["data"]["outputPath"],
        );
      } else if (msg["type"] == "reject") {
        tuxshare.rejectFile(
          msg["data"]["requestID"],
          msg["data"]["hash"],
          PeerInfo.fromJson(msg["data"]["peer"]),
        );
      }
    }
  }
}
