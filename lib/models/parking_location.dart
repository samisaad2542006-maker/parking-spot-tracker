class ParkingLocation {
  final int? id;
  final String areaName;
  final String floorNumber;
  final String spotNumber;
  final double? latitude;
  final double? longitude;
  final int updatedAt;

  ParkingLocation({
    this.id,
    required this.areaName,
    required this.floorNumber,
    required this.spotNumber,
    this.latitude,
    this.longitude,
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get hasGps => latitude != null && longitude != null;

  Map<String, Object?> toMap() => {
    'parking_id': id,
    'area_name': areaName,
    'floor_number': floorNumber,
    'spot_number': spotNumber,
    'latitude': latitude,
    'longitude': longitude,
    'updated_at': updatedAt,
  };

  factory ParkingLocation.fromMap(Map<String, Object?> m) => ParkingLocation(
    id: m['parking_id'] as int,
    areaName: m['area_name'] as String,
    floorNumber: m['floor_number'] as String,
    spotNumber: m['spot_number'] as String,
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    updatedAt: m['updated_at'] as int,
  );
}