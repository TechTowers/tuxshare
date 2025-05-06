/*
 * peer_info.dart
 * Store information about peers in the network.
 *
 * Author: Luka Pacar
 */

import 'dart:io';

/// PeerInfo is a class that stores information about peers in the network
class PeerInfo {
  /// Hostname of the peer
  final String hostname;
  /// IP address of the peer
  final InternetAddress address;

  const PeerInfo(this.hostname, this.address);

  @override
  bool operator ==(Object other) =>
      other is PeerInfo &&
          other.hostname == hostname &&
          other.address == address;

  @override
  int get hashCode => hostname.hashCode ^ address.hashCode;

  @override
  String toString() => '$hostname (${address.address})';
}
