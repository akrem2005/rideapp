class DriverLocation {
  final String driverId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final String carType;
  final bool isOnline;

  DriverLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    required this.carType,
    required this.isOnline,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId, // Send as String, not Pointer<_User>
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': {
          '__type': 'Date',
          'iso': updatedAt.toUtc().toIso8601String(),
        },
        'carType': carType,
        'isOnline': isOnline,
      };

  factory DriverLocation.fromJson(Map<String, dynamic> json) => DriverLocation(
        driverId: json['driverId'] is Map ? json['driverId']['objectId'] : json['driverId'],
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        updatedAt: DateTime.parse(json['updatedAt']['iso'] ?? json['updatedAt']),
        carType: json['carType'],
        isOnline: json['isOnline'],
      );
}