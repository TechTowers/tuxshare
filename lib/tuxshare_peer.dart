/*
 * tuxshare_peer.dart
 * Store information about peers in the network.
 *
 * Author: Luka Pacar
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tuxshare/peer_info.dart';

/// TuxSharePeer is a class that handles the discovery and data-handling of peers in the network
class TuxSharePeer {
  /// Multicast-Address that is used for discovery
  final InternetAddress _multicastAddress = InternetAddress("224.0.0.1");

  /// Port that is used for discovery
  final int _multicastPort = 6969;

  /// Message that is sent to discover peers
  final String _pingMessage = "TS_DISCOVERY_PING";

  /// Message that is sent as a response to the discovery message
  final String _responseMessage = "TS_DISCOVERY_PONG";

  /// Local hostname of the device
  late final String _localHostname;

  /// Socket for sending and receiving datagrams
  RawDatagramSocket? _socket;

  /// Set of discovered peers
  final Set<PeerInfo> _discoveredPeers = {};

  TuxSharePeer(this._localHostname);

  /// Starts listening for incoming datagrams
  Future<void> startListening() async {
    // Starts listening for incoming datagrams
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _multicastPort,
    );

    _socket!
      ..joinMulticast(_multicastAddress)
      ..listen(_onDatagram, onError: (e) => print('Socket-Error: $e'));
  }

  /// Sends a discovery message to neighbors
  Future<void> discover({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _discoveredPeers.clear();

    _socket?.send(utf8.encode(_pingMessage), _multicastAddress, _multicastPort);
    await Future.delayed(timeout);
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _socket!.receive();
    if (dg == null) return;

    final msg = utf8.decode(dg.data).trim();

    if (msg == _pingMessage) {
      // Received a discovery message
      final payload = jsonEncode({
        'msg': _responseMessage,
        'hostname': _localHostname,
      });
      // Send a response to the sender with local info
      _socket!.send(utf8.encode(payload), dg.address, dg.port);
    } else {
      // JSON-Antwort verarbeiten
      try {
        final map = jsonDecode(msg) as Map<String, dynamic>;
        if (map['msg'] == _responseMessage) {
          final peer = PeerInfo(map['hostname'] as String, dg.address);
          _discoveredPeers.add(peer);
        }
      } catch (_) {
        /* Ignoriere ungültige Nachrichten */
      }
    }
  }

  /// Socket schließen
  void close() => _socket?.close();

  /// Getter für die Liste der Peers
  Set<PeerInfo> getPeers() {
    return _discoveredPeers;
  }
}
