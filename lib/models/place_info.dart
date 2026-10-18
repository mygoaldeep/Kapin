class PlaceInfo {
  const PlaceInfo({
    required this.name,
    required this.lat,
    required this.lng,
    this.address = '',
    this.distanceM,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final double? distanceM;

  PlaceInfo withDistance(double? d) =>
      PlaceInfo(name: name, lat: lat, lng: lng, address: address, distanceM: d);
}
