/// A live-location share. Backend-agnostic; Firestore serialization lives in
/// `services/firebase_backend.dart`.
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

  ShareSession copyWith({
    double? latitude,
    double? longitude,
    String? address,
    bool? active,
    DateTime? updatedAt,
  }) =>
      ShareSession(
        id: id,
        ownerId: ownerId,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        address: address ?? this.address,
        active: active ?? this.active,
        expiresAt: expiresAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
