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

  /// Count of missed pings
  int _missedPings = 0;

  static const int _maxMissedPings = 2;

  PeerInfo(this.hostname, this.address);

  bool get isExpired => _missedPings > _maxMissedPings;

  @override
  bool operator ==(Object other) =>
      other is PeerInfo &&
      other.hostname == hostname &&
      other.address == address;

  @override
  int get hashCode => hostname.hashCode ^ address.hashCode;

  @override
  String toString() => '$hostname (${address.address})';

  void addMissedPing() {
    _missedPings++;
  }

  void resetMissedPings() {
    _missedPings = 0;
  }
}
