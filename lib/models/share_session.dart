import 'package:cloud_firestore/cloud_firestore.dart';

/// A live-location share. Field names match the original Kotlin app, so
/// existing Firestore data keeps working. `expiresAt` is epoch milliseconds.
class ShareSession {
  const ShareSession({
    required this.id,
    required this.ownerId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.active,
    required this.expiresAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final double latitude;
  final double longitude;
  final String address;
  final bool active;
  final DateTime expiresAt;
  final DateTime? updatedAt;

  bool get isLive => active && expiresAt.isAfter(DateTime.now());

  factory ShareSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const <String, dynamic>{};
    return ShareSession(
      id: doc.id,
      ownerId: m['ownerId'] as String? ?? '',
      latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
      address: m['address'] as String? ?? '',
      active: m['active'] as bool? ?? false,
      expiresAt: DateTime.fromMillisecondsSinceEpoch((m['expiresAt'] as num?)?.toInt() ?? 0),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'active': active,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
