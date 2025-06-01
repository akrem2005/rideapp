import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/ride_request_model.dart';

final isDriverOnlineProvider = StateProvider<bool>((ref) => false);

final incomingRideRequestProvider = StateProvider<RideRequest?>((ref) => null);
