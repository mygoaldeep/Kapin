String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// A place the user saved (home, work, school, ...).
class SavedPlace {
  SavedPlace({
    required this.id,
    required this.name,
    required this.kind,
    required this.lat,
    required this.lng,
    this.address = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String kind; // home | work | school | favorite | other
  final double lat;
  final double lng;
  final String address;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'lat': lat,
        'lng': lng,
        'address': address,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> m) => SavedPlace(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        kind: m['kind'] as String? ?? 'other',
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        address: m['address'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num?)?.toInt() ?? 0),
      );
}

/// A person in "Family & friends".
class FamilyMember {
  FamilyMember({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = 'family',
    this.isEmergency = false,
  });

  final String id;
  final String name;
  final String phone;
  final String relation; // family | friend
  final bool isEmergency;

  FamilyMember copyWith({String? name, String? phone, String? relation, bool? isEmergency}) =>
      FamilyMember(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relation: relation ?? this.relation,
        isEmergency: isEmergency ?? this.isEmergency,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
        'isEmergency': isEmergency,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> m) => FamilyMember(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        relation: m['relation'] as String? ?? 'family',
        isEmergency: m['isEmergency'] as bool? ?? false,
      );
}

/// One row of location history, a check-in, an SOS or a trip event.
class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.time,
    required this.lat,
    required this.lng,
    this.address = '',
    this.type = 'location', // location | checkin | sos | trip | arrival
    this.note = '',
  });

  final String id;
  final DateTime time;
  final double lat;
  final double lng;
  final String address;
  final String type;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'address': address,
        'type': type,
        'note': note,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> m) => HistoryEntry(
        id: m['id'] as String,
        time: DateTime.fromMillisecondsSinceEpoch((m['time'] as num?)?.toInt() ?? 0),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        address: m['address'] as String? ?? '',
        type: m['type'] as String? ?? 'location',
        note: m['note'] as String? ?? '',
      );
}

/// A shared trip toward a destination.
class TripRecord {
  TripRecord({
    required this.id,
    required this.name,
    required this.destName,
    required this.destLat,
    required this.destLng,
    required this.startedAt,
    required this.plannedEnd,
    this.destAddress = '',
    this.endedAt,
    this.status = 'active', // active | arrived | stopped | expired | ended
    this.shareId = '',
    this.recipients = const [],
  });

  final String id;
  final String name;
  final String destName;
  final String destAddress;
  final double destLat;
  final double destLng;
  final DateTime startedAt;
  final DateTime plannedEnd;
  final DateTime? endedAt;
  final String status;
  final String shareId;
  final List<String> recipients;

  bool get isActive => status == 'active';

  TripRecord copyWith({String? status, DateTime? endedAt}) => TripRecord(
        id: id,
        name: name,
        destName: destName,
        destAddress: destAddress,
        destLat: destLat,
        destLng: destLng,
        startedAt: startedAt,
        plannedEnd: plannedEnd,
        endedAt: endedAt ?? this.endedAt,
        status: status ?? this.status,
        shareId: shareId,
        recipients: recipients,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'destName': destName,
        'destAddress': destAddress,
        'destLat': destLat,
        'destLng': destLng,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'plannedEnd': plannedEnd.millisecondsSinceEpoch,
        'endedAt': endedAt?.millisecondsSinceEpoch,
        'status': status,
        'shareId': shareId,
        'recipients': recipients,
      };

  factory TripRecord.fromJson(Map<String, dynamic> m) => TripRecord(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        destName: m['destName'] as String? ?? '',
        destAddress: m['destAddress'] as String? ?? '',
        destLat: (m['destLat'] as num).toDouble(),
        destLng: (m['destLng'] as num).toDouble(),
        startedAt: DateTime.fromMillisecondsSinceEpoch((m['startedAt'] as num?)?.toInt() ?? 0),
        plannedEnd: DateTime.fromMillisecondsSinceEpoch((m['plannedEnd'] as num?)?.toInt() ?? 0),
        endedAt: m['endedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((m['endedAt'] as num).toInt()),
        status: m['status'] as String? ?? 'ended',
        shareId: m['shareId'] as String? ?? '',
        recipients: ((m['recipients'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}
