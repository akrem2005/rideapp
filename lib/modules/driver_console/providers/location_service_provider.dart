import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/location_service.dart';

final locationServiceProvider =
    Provider.family<LocationService, String>((ref, driverId) {
  return LocationService(driverId: driverId);
});
