import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/ride_request_service.dart';

final rideRequestServiceProvider = Provider((ref) => RideRequestService());
