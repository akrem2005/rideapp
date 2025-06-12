class RideRequest {
  final String? id; // Nullable for local use, maps to objectId
  final String riderId; // Pointer to _User
  final String pickup;
  final String destination;
  final String carType;
  final double pickupLatitude;
  final double pickupLongitude;
  final DateTime createdAt;

  RideRequest({
    this.id,
    required this.riderId,
    required this.pickup,
    required this.destination,
    required this.carType,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'pickup': pickup,
        'destination': destination,
        'carType': carType,
        'pickupLatitude': pickupLatitude,
        'pickupLongitude': pickupLongitude,
        'createdAt': {
          '__type': 'Date',
          'iso': createdAt.toUtc().toIso8601String(),
        },
        // Exclude id and riderId (set as pointer in requestJson)
      };

  factory RideRequest.fromJson(Map<String, dynamic> json) => RideRequest(
        id: json['objectId'] ?? json['id'],
        riderId: json['riderId']?['objectId'] ?? json['riderId'],
        pickup: json['pickup'],
        destination: json['destination'],
        carType: json['carType'],
        pickupLatitude: json['pickupLatitude']?.toDouble(),
        pickupLongitude: json['pickupLongitude']?.toDouble(),
        createdAt:
            DateTime.parse(json['createdAt']['iso'] ?? json['createdAt']),
      );
}
