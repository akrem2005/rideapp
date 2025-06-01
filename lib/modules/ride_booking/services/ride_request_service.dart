import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class RideRequestService {
  Future<void> sendRideRequest({
    required String pickupLocation,
    required String destination,
    required String carType,
  }) async {
    final rideRequest = ParseObject('RideRequest')
      ..set('pickupLocation', pickupLocation)
      ..set('destination', destination)
      ..set('carType', carType);

    final response = await rideRequest.save();

    if (!response.success) {
      throw Exception(
          'Failed to save ride request: ${response.error?.message}');
    }
  }
}
