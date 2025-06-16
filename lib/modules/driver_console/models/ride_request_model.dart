class RideRequest {
  final String? objectId;
  final String riderId;
  final String pickup;
  final String destination;
  final String carType;
  final double pickupLatitude;
  final double pickupLongitude;
  final String createdAt;
  final String? assignedDriverId; // Add this field

  RideRequest({
    this.objectId,
    required this.riderId,
    required this.pickup,
    required this.destination,
    required this.carType,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.createdAt,
    this.assignedDriverId,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      objectId: json['objectId'] as String?,
      riderId: json['riderId'] as String,
      pickup: json['pickup'] as String,
      destination: json['destination'] as String,
      carType: json['carType'] as String,
      pickupLatitude: (json['pickupLatitude'] as num).toDouble(),
      pickupLongitude: (json['pickupLongitude'] as num).toDouble(),
      createdAt: json['createdAt'] as String,
      assignedDriverId: json['assignedDriverId']?['objectId']
          as String?, // Extract objectId from pointer
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'objectId': objectId,
      'riderId': riderId,
      'pickup': pickup,
      'destination': destination,
      'carType': carType,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'createdAt': createdAt,
      if (assignedDriverId != null)
        'assignedDriverId': {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': assignedDriverId,
        },
    };
  }
}
