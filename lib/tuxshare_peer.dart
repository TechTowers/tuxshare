import "dart:async";
import "dart:convert";
import "dart:io";

import "package:tuxshare/peer_info.dart";

/// TuxSharePeer is a class that handles the discovery and data-handling of peers in the network
class TuxSharePeer {
  /// Multicast-Address that is used for discovery
  final InternetAddress _multicastAddress;

  /// Port that is used for discovery
  final int _multicastPort;

  /// Message that is sent to discover peers
  final String _pingMessage;

  /// Message that is sent as a response to the discovery message
  final String _responseMessage;

  /// Local hostname of the device
  late final String _localHostname;

  /// Socket for sending and receiving datagrams
  RawDatagramSocket? _socket;

  /// Timer for periodic discovery
  Timer? _discoveryTimer;

  /// Set of discovered peers
  final Set<PeerInfo> _discoveredPeers = {};

  TuxSharePeer(
    this._localHostname, {
    InternetAddress? multicastAddress,
    int multicastPort = 6969,
    String pingMessage = "TS_DISCOVERY_PING",
    String responseMessage = "TS_DISCOVERY_PONG",
  }) : _multicastAddress = multicastAddress ?? InternetAddress("224.0.0.1"),
       _multicastPort = multicastPort,
       _pingMessage = pingMessage,
       _responseMessage = responseMessage;

  /// Starts listening for incoming datagrams
  Future<void> startListening() async {
    // Starts listening for incoming datagrams
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _multicastPort,
    );

    _socket!
      ..multicastLoopback = true
      ..joinMulticast(_multicastAddress)
      ..listen(_onDatagram, onError: (e) => print("Socket-Error: $e"));
  }

  /// Sends a discovery message to neighbors
  Future<void> discover() async {
    _discoveredPeers.clear();

    // Send the discovery ping
    _socket?.send(utf8.encode(_pingMessage), _multicastAddress, _multicastPort);
  }

  Future<void> startDiscoveryLoop({
    Duration interval = const Duration(seconds: 5),
  }) async {
    _discoveryTimer = Timer.periodic(interval, (_) async {
      discover();
    });
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _socket!.receive();
    if (dg == null) return;

    final msg = utf8.decode(dg.data).trim();

    if (msg == _pingMessage) {
      // Received a discovery message
      final payload = jsonEncode({
        "msg": _responseMessage,
        "hostname": _localHostname,
      });
      // Send a response to the sender with local info
      _socket!.send(utf8.encode(payload), dg.address, dg.port);
    } else {
      try {
        final map = jsonDecode(msg) as Map<String, dynamic>;
        if (map["msg"] == _responseMessage) {
          final peer = PeerInfo(map["hostname"] as String, dg.address);
          _discoveredPeers.add(peer);
        }
      } catch (_) {}
    }
  }

  void close() {
    _discoveryTimer?.cancel();
    _socket?.close();
  }

  Set<PeerInfo> getPeers() {
    return _discoveredPeers;
  }
}
