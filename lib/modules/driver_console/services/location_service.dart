import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class LocationService {
  final String driverId;

  LocationService({required this.driverId});

  Future<bool> sendLocation(LatLng location) async {
    final query = QueryBuilder<ParseObject>(ParseObject('DriverLocation'))
      ..whereEqualTo('driverId', driverId);

    final existing = await query.query();

    ParseObject locationObject;

    if (existing.results != null && existing.results!.isNotEmpty) {
      // Update existing object
      locationObject = existing.results!.first as ParseObject;
    } else {
      // Create new object
      locationObject = ParseObject('DriverLocation');
    }

    locationObject
      ..set('driverId', driverId)
      ..set('latitude', location.latitude)
      ..set('longitude', location.longitude)
      ..set('updatedAt', DateTime.now());

    final response = await locationObject.save();
    return response.success;
  }

  Future<bool> deleteLocation() async {
    final query = QueryBuilder<ParseObject>(ParseObject('DriverLocation'))
      ..whereEqualTo('driverId', driverId);

    final result = await query.query();

    if (result.success &&
        result.results != null &&
        result.results!.isNotEmpty) {
      for (final obj in result.results!) {
        await (obj as ParseObject).delete();
      }
      return true;
    }

    return false;
  }
}
