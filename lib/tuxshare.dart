import "dart:async";
import "dart:convert";
import "dart:io";

import "package:tuxshare/peer_info.dart";

/// TuxShare is a class that handles the discovery and data-handling of peers in the network
class TuxShare {
  /// Multicast-Address that is used for discovery
  final InternetAddress _multicastAddress;

  /// Port that is used for discovery
  final int _multicastPort;

  /// Message that is sent to discover peers
  final String _pingMessage;

  /// Message that is sent as a response to the discovery message
  final String _responseMessage;

  /// Message that is sent to offer to send a file
  final String _offerMessage;

  /// Message that is sent when an offer fails
  final String _offerFailMessage;

  /// Message that is sent when an offer is accepted
  final String _offerAcceptMessage;

  /// Message that is sent when an offer is rejected
  final String _offerRejectMessage;

  /// Local hostname of the device
  late final String _localHostname;

  /// Socket for sending and receiving datagrams
  RawDatagramSocket? _socket;

  /// Timer for periodic discovery
  Timer? _discoveryTimer;

  /// Set of discovered peers
  final Set<PeerInfo> _discoveredPeers = {};

  /// Map for sending
  final Map<int, dynamic> _sendingTo = {};

  /// Request thingies
  int _requestCounter = 0;
  final Map<int, dynamic> _requests = {};

  /// optional callback functions
  void Function(PeerInfo peer)? onPeerDiscovered;
  void Function(PeerInfo peer)? onPeerForget;
  void Function(Map<String, dynamic>)? onSendOfferFail;
  void Function(Map<int, dynamic>)? onRequest;
  void Function(Map<String, dynamic>)? onRequestReject;
  void Function(String)? onFileReceived;
  void Function(PeerInfo, String, Object)? onSendingFileError;
  void Function(String, Object)? onReceivingFileError;

  TuxShare(
    this._localHostname, {
    InternetAddress? multicastAddress,
    int multicastPort = 6969,
    String pingMessage = "TS_DISCOVERY_PING",
    String responseMessage = "TS_DISCOVERY_PONG",
    String offerMessage = "TS_OFFER",
    String offerFailMessage = "TS_OFFER_FAIL",
    String offerAcceptMessage = "TS_OFFER_ACCEPT",
    String offerRejectMessage = "TS_OFFER_REJECT",
  }) : _multicastAddress = multicastAddress ?? InternetAddress("224.0.0.1"),
       _multicastPort = multicastPort,
       _pingMessage = pingMessage,
       _responseMessage = responseMessage,
       _offerMessage = offerMessage,
       _offerFailMessage = offerFailMessage,
       _offerAcceptMessage = offerAcceptMessage,
       _offerRejectMessage = offerRejectMessage;

  Set<PeerInfo> get peers => _discoveredPeers;

  PeerInfo getPeerFromHostname(String hostname) {
    return _discoveredPeers.firstWhere((peer) => peer.hostname == hostname);
  }

  /// Starts listening for incoming datagrams
  Future<void> startListening() async {
    // Starts listening for incoming datagrams
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _multicastPort,
    );

    _socket!
      ..multicastLoopback = false
      ..listen(_onDatagram, onError: (e) => print("Socket-Error: $e"));

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );

    for (final iface in interfaces) {
      if (!iface.name.toLowerCase().contains("tailscale")) {
        _socket!.joinMulticast(_multicastAddress, iface);
      }
    }
  }

  /// Sends a discovery message to neighbors
  Future<void> discover() async {
    for (var peer in _discoveredPeers) {
      peer.addMissedPing();
    }

    // Remove expired peers
    _discoveredPeers.removeWhere((p) {
      if (p.isExpired) {
        onPeerForget?.call(p);
        return true;
      }
      return false;
    });

    // Send the discovery ping
    _socket?.send(utf8.encode(_pingMessage), _multicastAddress, _multicastPort);
  }

  Future<void> startDiscoveryLoop({
    Duration interval = const Duration(seconds: 5),
  }) async {
    _discoveryTimer = Timer.periodic(interval, (_) async {
      await discover();
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
      final map = jsonDecode(msg) as Map<String, dynamic>;
      if (map["msg"] == _responseMessage) {
        final peer = PeerInfo(map["hostname"] as String, dg.address);
        final existingPeer = _discoveredPeers.lookup(peer);
        if (existingPeer != null) {
          existingPeer.resetMissedPings(); // Renew TTL
        } else {
          _discoveredPeers.add(peer); // New peer
          onPeerDiscovered?.call(peer);
        }
      } else if (map["msg"] == _offerMessage) {
        try {
          final data = {
            ...map["data"],
            "peer": getPeerFromHostname(map["data"]["peer"]),
          };

          _requests[_requestCounter] = data;
          onRequest?.call({_requestCounter: map["data"]});
          _requestCounter++;
        } on StateError catch (_) {
          final payload = jsonEncode({
            "msg": _offerFailMessage,
            "data": map["data"]["hash"],
          });
          _socket!.send(utf8.encode(payload), dg.address, dg.port);
        }
      } else if (map["msg"] == _offerFailMessage) {
        onSendOfferFail?.call(_sendingTo[map["data"]]);
      } else if (map["msg"] == _offerAcceptMessage) {
        final request = _sendingTo.remove(map["data"]["hash"]);
        sendFile(request["peer"], File(request["file"]));
      } else if (map["msg"] == _offerRejectMessage) {
        final request = _sendingTo.remove(map["data"]["hash"]);
        onRequestReject?.call(request);
      }
    }
  }

  void close() {
    _discoveryTimer?.cancel();
    _socket?.close();
  }

  /// Send a file to Peer
  Future<void> sendOffer(PeerInfo peer, File file, {int port = 9696}) async {
    int hash = Object.hash(peer.hostname, file.path);
    _sendingTo[hash] = {
      "peer": peer,
      "file": file.path,
      "size": await file.length(),
      "hash": hash,
    };

    _socket?.send(
      utf8.encode(
        jsonEncode({
          "msg": _offerMessage,
          "data": {
            ..._sendingTo[hash],
            ...{"peer": _localHostname},
          },
        }),
      ),
      peer.address,
      _multicastPort,
    );
  }

  /// Send a file to a peer
  Future<void> sendFile(
    PeerInfo destinationPeer,
    File file, {
    int port = 9696,
  }) async {
    late Socket socket;
    try {
      socket = await Socket.connect(
        destinationPeer.address,
        port,
      ).catchError((e) => throw e);
    } catch (e) {
      onSendingFileError?.call(destinationPeer, file.path, e);
      return;
    }

    try {
      await socket.addStream(file.openRead());
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  String getDefaultDownloadsPath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return '$userProfile\\Downloads';
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Downloads';
      }
    }

    // Fallback to current directory if all else fails
    return Directory.current.path;
  }

  String expandHome(String path) {
    if (path.startsWith('~')) {
      final home =
          Platform.isWindows
              ? Platform.environment['USERPROFILE']
              : Platform.environment['HOME'];
      if (home != null) {
        return path.replaceFirst('~', home);
      }
    }
    return path;
  }

  String resolveDestinationPath(String outputPath, String originalFilename) {
    String input = outputPath.trim();
    if (input.endsWith(Platform.pathSeparator)) {
      input = input.substring(0, input.length - 1);
    }

    final expanded = expandHome(input);
    final fileOrDir = File(expanded);
    final dir = Directory(expanded);

    if (input.isEmpty) {
      return '${getDefaultDownloadsPath()}${Platform.pathSeparator}$originalFilename';
    }

    if (dir.existsSync()) {
      return '${dir.path}${Platform.pathSeparator}$originalFilename';
    } else if (fileOrDir.parent.existsSync()) {
      return fileOrDir.path;
    } else {
      return '${getDefaultDownloadsPath()}${Platform.pathSeparator}$input';
    }
  }

  /// Send a file to Peer
  Future<void> acceptFile(
    int requestID,
    int fileHash,
    PeerInfo peer,
    String? outputPath, // Raw user input
  ) async {
    // Extract original filename from request info
    final request = _requests[requestID];
    final originalFilename = File(request["file"]).uri.pathSegments.last;

    // Resolve destination file path
    final resolvedPath = resolveDestinationPath(
      outputPath ?? "",
      originalFilename,
    );

    // Notify peer of acceptance
    _socket?.send(
      utf8.encode(
        jsonEncode({
          "msg": _offerAcceptMessage,
          "data": {"peer": _localHostname, "hash": fileHash},
        }),
      ),
      peer.address,
      _multicastPort,
    );

    // Begin receiving the file
    receiveFile(File(resolvedPath));
  }

  /// Receive a file from a Peer
  Future<void> receiveFile(File outputPath, {int port = 9696}) async {
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);

    await for (Socket socket in server) {
      final file = (outputPath);
      final sink = file.openWrite();

      try {
        await for (final data in socket) {
          sink.add(data);
        }
        await sink.close();
        onFileReceived?.call(outputPath.path);
        await socket.close();
        break;
      } catch (e) {
        await sink.close();
        await socket.close();
        onReceivingFileError?.call(outputPath.path, e);
      }
    }
  }

  Future<void> rejectFile(int fileHash, PeerInfo peer) async {
    _socket?.send(
      utf8.encode(
        jsonEncode({
          "msg": _offerRejectMessage,
          "data": {"hash": fileHash},
        }),
      ),
      peer.address,
      _multicastPort,
    );
  }
}
