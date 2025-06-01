import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class LocationService {
  Future<bool> sendLocation(LatLng location) async {
    final driverLocation = ParseObject('DriverLocation')
      ..set('latitude', location.latitude)
      ..set('longitude', location.longitude)
      ..set('updatedAt', DateTime.now());

    final response = await driverLocation.save();

    return response.success;
  }
}
