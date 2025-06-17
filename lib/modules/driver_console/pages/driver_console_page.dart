import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/ride_request_model.dart';
import '../models/driver_location_model.dart';
import '../../auth/pages/get_started_page.dart';

// Constants
const String back4appBaseUrl = 'https://parseapi.back4app.com';
const String appId = "jU5yWVbYCi4B44T5SncVHDitWJhnzR1P9dKmo73y";
const String restApiKey = "hoH5efGxj37mG5fj3MQq2nDxXceK3VVsoW9csD5z";

// Enums
enum RideStatus { none, incoming, accepted, start, onroute, finished }

// Riverpod Providers
final rideStatusProvider = StateProvider<RideStatus>((ref) => RideStatus.none);
final isDriverOnlineProvider = StateProvider<bool>((ref) => false);
final driverIdProvider = StateProvider<String?>((ref) => null);
final rideRequestProvider = StateProvider<RideRequest?>((ref) => null);
final pickupPositionProvider = StateProvider<LatLng?>((ref) => null);
final driverPositionProvider = StateProvider<LatLng?>((ref) => null);
final carTypeProvider = StateProvider<String>((ref) => 'Economy');

final driverServiceProvider = Provider<DriverService>((ref) {
  return DriverService(ref);
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Services
class DriverService {
  final Ref ref;

  DriverService(this.ref);

  Future<void> initializeDriver(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driverObjectId') ??
        'driver_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('driverObjectId', driverId);
    ref.read(driverIdProvider.notifier).state = driverId;

    final position =
        await ref.read(locationServiceProvider).getCurrentLocation(context);
    if (position != null) {
      ref.read(driverPositionProvider.notifier).state = position;
    }
  }

  Future<void> toggleOnlineStatus({
    required BuildContext context,
    required bool isOnline,
    required String driverId,
    required LatLng position,
    required String carType,
  }) async {
    try {
      await _updateDriverLocation(
        context: context,
        driverId: driverId,
        position: position,
        isOnline: isOnline,
        carType: carType,
      );
      ref.read(isDriverOnlineProvider.notifier).state = isOnline;

      if (!isOnline) {
        ref.read(rideStatusProvider.notifier).state = RideStatus.none;
        ref.read(rideRequestProvider.notifier).state = null;
        ref.read(pickupPositionProvider.notifier).state = null;
      }
    } catch (e) {
      print('Toggle error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle status: $e')),
      );
      rethrow;
    }
  }

  Future<void> pollRideRequests({
    required BuildContext context,
    required String driverId,
    required String carType,
  }) async {
    try {
      final queryJson = {
        "\$or": [
          {
            "status": "pending",
            "carType": carType,
            "assignedDriverId": null,
          },
          {
            "status": "pending",
            "carType": carType,
            "assignedDriverId": {
              "__type": "Pointer",
              "className": "_User",
              "objectId": driverId,
            },
          },
          {
            "status": "accepted",
            "assignedDriverId": {
              "__type": "Pointer",
              "className": "_User",
              "objectId": driverId,
            },
          },
          {
            "status": "start",
            "assignedDriverId": {
              "__type": "Pointer",
              "className": "_User",
              "objectId": driverId,
            },
          },
          {
            "status": "onroute",
            "assignedDriverId": {
              "__type": "Pointer",
              "className": "_User",
              "objectId": driverId,
            },
          },
        ],
      };
      print('Poll Ride Requests Query: $queryJson');
      final response = await http.get(
        Uri.parse(
            '$back4appBaseUrl/classes/RideRequest?where=${Uri.encodeComponent(jsonEncode(queryJson))}'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Poll Ride Requests Response: $data');
        if (data['results'] != null && data['results'].isNotEmpty) {
          final requestData = data['results'][0];
          final newRideRequest = RideRequest.fromJson({
            'objectId': requestData['objectId'] ?? '',
            'riderId': requestData['riderId']?['objectId'] ?? 'Unknown',
            'pickup': requestData['pickup'] ?? 'Unknown',
            'destination': requestData['destination'] ?? 'Unknown',
            'carType': requestData['carType'] ?? 'Unknown',
            'pickupLatitude': requestData['pickupLatitude']?.toDouble() ?? 0.0,
            'pickupLongitude':
                requestData['pickupLongitude']?.toDouble() ?? 0.0,
            'createdAt': requestData['createdAt']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
          });

          ref.read(rideRequestProvider.notifier).state = newRideRequest;
          ref.read(pickupPositionProvider.notifier).state = LatLng(
            requestData['pickupLatitude']?.toDouble() ?? 0.0,
            requestData['pickupLongitude']?.toDouble() ?? 0.0,
          );

          final status = requestData['status'];
          print('Ride status from backend: $status');
          if (status == 'pending') {
            ref.read(rideStatusProvider.notifier).state = RideStatus.incoming;
          } else if (status == 'accepted') {
            ref.read(rideStatusProvider.notifier).state = RideStatus.accepted;
          } else if (status == 'start') {
            ref.read(rideStatusProvider.notifier).state = RideStatus.start;
          } else if (status == 'onroute') {
            ref.read(rideStatusProvider.notifier).state = RideStatus.onroute;
          } else {
            print('Unexpected ride status: $status');
            _clearRideState();
          }
        } else {
          print('No ride requests found for driverId: $driverId');
          if (ref.read(rideRequestProvider) != null &&
              [
                RideStatus.incoming,
                RideStatus.accepted,
                RideStatus.start,
                RideStatus.onroute
              ].contains(ref.read(rideStatusProvider))) {
            print('Clearing stale ride request');
            _clearRideState();
          }
        }
      } else {
        final errorBody = jsonDecode(response.body);
        print('Poll error: $errorBody');
        throw Exception(
            'Error polling rides: ${errorBody['error'] ?? 'Unknown error'} (Code: ${response.statusCode})');
      }
    } catch (e) {
      print('Error polling rides: $e');
      if (ref.read(rideRequestProvider) == null &&
          ref.read(isDriverOnlineProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error polling rides: $e')),
        );
      }
      rethrow;
    }
  }

  Future<void> acceptRideRequest({
    required BuildContext context,
    required String objectId,
    required String driverId,
  }) async {
    try {
      final updateJson = {
        'status': 'accepted',
        'assignedDriverId': {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': driverId,
        },
      };
      print('Accept Ride Request Payload: $updateJson');
      final response = await http.put(
        Uri.parse('$back4appBaseUrl/classes/RideRequest/$objectId'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateJson),
      );
      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        print('Accept Ride Error: $errorBody');
        throw Exception(
            'Failed to accept ride: ${errorBody['error'] ?? 'Unknown error'} (Code: ${response.statusCode})');
      }
      print('Accept Ride Response: ${jsonDecode(response.body)}');
      ref.read(rideStatusProvider.notifier).state = RideStatus.accepted;
    } catch (e) {
      print('Error accepting ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting ride: $e')),
      );
      rethrow;
    }
  }

  Future<void> rejectRideRequest({
    required BuildContext context,
    required String objectId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$back4appBaseUrl/classes/RideRequest/$objectId'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': 'rejected',
          'assignedDriverId': null,
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        print('Reject Ride Error: $errorBody');
        throw Exception(
            'Failed to reject ride: ${errorBody['error'] ?? 'Unknown error'} (Code: ${response.statusCode})');
      }
      print('Reject Ride Response: ${jsonDecode(response.body)}');
      _clearRideState();
    } catch (e) {
      print('Error rejecting ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting ride: $e')),
      );
      rethrow;
    }
  }

  void _clearRideState() {
    ref.read(rideStatusProvider.notifier).state = RideStatus.none;
    ref.read(rideRequestProvider.notifier).state = null;
    ref.read(pickupPositionProvider.notifier).state = null;
  }

  Future<void> _updateDriverLocation({
    required BuildContext context,
    required String driverId,
    required LatLng position,
    required bool isOnline,
    required String carType,
  }) async {
    final driverLocation = DriverLocation(
      driverId: driverId,
      latitude: position.latitude,
      longitude: position.longitude,
      updatedAt: DateTime.now().toUtc(),
      carType: carType,
      isOnline: isOnline,
    );

    try {
      final queryJson = {"driverId": driverId};
      print('Query DriverLocation: $queryJson');
      final queryResponse = await http.get(
        Uri.parse(
            '$back4appBaseUrl/classes/DriverLocation?where=${Uri.encodeComponent(jsonEncode(queryJson))}'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
        },
      );

      if (queryResponse.statusCode != 200) {
        final errorBody = jsonDecode(queryResponse.body);
        print('Query Driver Error: $errorBody');
        throw Exception(
            'Failed to query driver location: ${errorBody['error'] ?? 'Unknown error'} (Code: ${queryResponse.statusCode})');
      }

      final queryData = jsonDecode(queryResponse.body);
      print('Query Driver Response: $queryData');

      if (queryData['results'] != null && queryData['results'].isNotEmpty) {
        final objectId = queryData['results'][0]['objectId'];
        final updateJson = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updatedAt': {
            '__type': 'Date',
            'iso': driverLocation.updatedAt.toIso8601String(),
          },
          'carType': carType,
          'isOnline': isOnline,
        };
        print('Update DriverLocation Payload: $updateJson');
        final updateResponse = await http.put(
          Uri.parse('$back4appBaseUrl/classes/DriverLocation/$objectId'),
          headers: {
            'X-Parse-Application-Id': appId,
            'X-Parse-REST-API-Key': restApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updateJson),
        );

        if (updateResponse.statusCode != 200) {
          final errorBody = jsonDecode(updateResponse.body);
          print('Update Driver Error: $errorBody');
          throw Exception(
              'Failed to update driver location: ${errorBody['error'] ?? 'Unknown error'} (Code: ${updateResponse.statusCode})');
        }
        print('Update Driver Response: ${jsonDecode(updateResponse.body)}');
      } else {
        final createJson = driverLocation.toJson();
        print('Create DriverLocation Payload: $createJson');
        final createResponse = await http.post(
          Uri.parse('$back4appBaseUrl/classes/DriverLocation'),
          headers: {
            'X-Parse-Application-Id': appId,
            'X-Parse-REST-API-Key': restApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(createJson),
        );

        if (createResponse.statusCode != 201) {
          final errorBody = jsonDecode(createResponse.body);
          print('Create Driver Error: $errorBody');
          throw Exception(
              'Failed to create driver location: ${errorBody['error'] ?? 'Unknown error'} (Code: ${createResponse.statusCode})');
        }
        print('Create Driver Response: ${jsonDecode(createResponse.body)}');
      }
    } catch (e) {
      print('Error updating driver location: $e');
      throw e;
    }
  }

  Future<void> updateRideStatus({
    required BuildContext context,
    required String objectId,
    required String status,
  }) async {
    try {
      final updateJson = {
        'status': status,
      };
      print('Update Ride Status Payload: $updateJson');
      final response = await http.put(
        Uri.parse('$back4appBaseUrl/classes/RideRequest/$objectId'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateJson),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        print('Update Ride Status Error: $errorBody');
        throw Exception(
            'Failed to update ride status: ${errorBody['error'] ?? 'Unknown error'} (Code: ${response.statusCode})');
      }
      print('Update Ride Status Response: ${jsonDecode(response.body)}');
    } catch (e) {
      print('Error updating ride status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating ride status: $e')),
      );
      rethrow;
    }
  }
}

class LocationService {
  Future<LatLng?> getCurrentLocation(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions permanently denied')),
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
      return null;
    }
  }
}

class DriverConsolePage extends HookConsumerWidget {
  const DriverConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapController = useMemoized(() => MapController());
    final isToggling = useState<bool>(false);
    final ridePollTimer = useRef<Timer?>(null);
    final locationUpdateTimer = useRef<Timer?>(null);
    final isRidePolling = useState<bool>(false);

    useEffect(() {
      ref.read(driverServiceProvider).initializeDriver(context);
      return () {
        ridePollTimer.value?.cancel();
        locationUpdateTimer.value?.cancel();
      };
    }, []);

    // Polling for ride requests
    useEffect(() {
      final isOnline = ref.watch(isDriverOnlineProvider);
      final driverId = ref.watch(driverIdProvider);
      final position = ref.watch(driverPositionProvider);
      final carType = ref.watch(carTypeProvider);
      final rideStatus = ref.watch(rideStatusProvider);

      if (!isOnline ||
          driverId == null ||
          position == null ||
          ![RideStatus.none, RideStatus.incoming].contains(rideStatus)) {
        ridePollTimer.value?.cancel();
        isRidePolling.value = false;
        return null;
      }

      if (isRidePolling.value) return null;

      isRidePolling.value = true;
      ridePollTimer.value?.cancel();

      Future<void> pollRides() async {
        try {
          await ref.read(driverServiceProvider).pollRideRequests(
                context: context,
                driverId: driverId,
                carType: carType,
              );
        } catch (e) {
          print('Ride polling error: $e');
          if (ref.read(rideRequestProvider) == null && isOnline) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error polling rides: $e')),
            );
          }
        }
      }

      pollRides();
      ridePollTimer.value =
          Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!isRidePolling.value ||
            ![RideStatus.none, RideStatus.incoming]
                .contains(ref.read(rideStatusProvider))) {
          ridePollTimer.value?.cancel();
          isRidePolling.value = false;
          return;
        }
        await pollRides();
      });

      return () {
        ridePollTimer.value?.cancel();
        isRidePolling.value = false;
      };
    }, [
      ref.watch(isDriverOnlineProvider),
      ref.watch(driverIdProvider),
      ref.watch(driverPositionProvider),
      ref.watch(carTypeProvider),
      ref.watch(rideStatusProvider),
    ]);

    // Separate polling for driver location updates
    useEffect(() {
      final isOnline = ref.watch(isDriverOnlineProvider);
      final driverId = ref.watch(driverIdProvider);
      final position = ref.watch(driverPositionProvider);
      final carType = ref.watch(carTypeProvider);

      if (!isOnline || driverId == null || position == null) {
        locationUpdateTimer.value?.cancel();
        return null;
      }

      Future<void> updateLocation() async {
        try {
          await ref.read(driverServiceProvider).toggleOnlineStatus(
                context: context,
                isOnline: isOnline,
                driverId: driverId,
                position: position,
                carType: carType,
              );
        } catch (e) {
          print('Location update error: $e');
        }
      }

      updateLocation();
      locationUpdateTimer.value =
          Timer.periodic(const Duration(seconds: 10), (_) async {
        await updateLocation();
      });

      return () {
        locationUpdateTimer.value?.cancel();
      };
    }, [
      ref.watch(isDriverOnlineProvider),
      ref.watch(driverIdProvider),
      ref.watch(driverPositionProvider),
      ref.watch(carTypeProvider),
    ]);

    final position = ref.watch(driverPositionProvider);
    if (position == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text("Driver Console"),
        actions: [
          Row(
            children: [
              Text(
                ref.watch(isDriverOnlineProvider) ? "Online" : "Offline",
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Switch(
                activeColor: Colors.orange,
                value: ref.watch(isDriverOnlineProvider),
                onChanged: isToggling.value
                    ? null
                    : (value) async {
                        final driverId = ref.read(driverIdProvider);
                        final position = ref.read(driverPositionProvider);
                        final carType = ref.read(carTypeProvider);
                        if (driverId == null || position == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Driver ID or location unavailable')),
                          );
                          return;
                        }
                        isToggling.value = true;
                        try {
                          await ref
                              .read(driverServiceProvider)
                              .toggleOnlineStatus(
                                context: context,
                                isOnline: value,
                                driverId: driverId,
                                position: position,
                                carType: carType,
                              );
                        } finally {
                          isToggling.value = false;
                        }
                      },
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: position,
              zoom: 15.0,
              maxZoom: 18,
              minZoom: 3,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.ride_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: position,
                    width: 40,
                    height: 40,
                    builder: (ctx) => const Icon(Icons.my_location,
                        color: Colors.blue, size: 30),
                  ),
                  if (ref.watch(pickupPositionProvider) != null)
                    Marker(
                      point: ref.watch(pickupPositionProvider)!,
                      width: 50,
                      height: 50,
                      builder: (ctx) => const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                ],
              ),
            ],
          ),
          Consumer(
            builder: (context, ref, child) {
              final rideStatus = ref.watch(rideStatusProvider);
              final rideRequest = ref.watch(rideRequestProvider);
              final driverId = ref.watch(driverIdProvider);
              if (rideStatus != RideStatus.none &&
                  rideRequest != null &&
                  driverId != null) {
                return _rideBottomSheet(
                    context, ref, rideRequest, driverId, mapController);
              }
              return const SizedBox.shrink();
            },
          ),
          if (ref.watch(isDriverOnlineProvider) &&
              ref.watch(rideStatusProvider) == RideStatus.none)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: const Text(
                  "Waiting for ride requests...",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFFA500)),
            child: Row(
              children: const [
                CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('lib/shared/assets/user.png')),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "John Doe",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _drawerItem(context, CupertinoIcons.time, 'Trip Orders', () {}),
                _drawerItem(context, CupertinoIcons.cart, 'Promotions', () {}),
                _drawerItem(
                    context, CupertinoIcons.settings, 'Settings', () {}),
                _drawerItem(context, CupertinoIcons.question, 'Help', () {}),
                _drawerItem(context, CupertinoIcons.arrow_left_circle, 'Logout',
                    () => logout(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _rideBottomSheet(
    BuildContext context,
    WidgetRef ref,
    RideRequest request,
    String driverId,
    MapController mapController,
  ) {
    final rideStatus = ref.watch(rideStatusProvider);

    String statusText;
    String nextButtonText;
    RideStatus? nextState;
    String? nextBackendStatus;
    bool showRejectButton = rideStatus == RideStatus.incoming;

    switch (rideStatus) {
      case RideStatus.incoming:
        statusText = "New Ride Request";
        nextButtonText = "Accept";
        nextState = RideStatus.accepted;
        nextBackendStatus = null;
        break;
      case RideStatus.accepted:
        statusText = "Accepted - Navigating to pickup...";
        nextButtonText = "Start Ride";
        nextState = RideStatus.start;
        nextBackendStatus = 'start';
        break;
      case RideStatus.start:
        statusText = "Ride started - Heading to pickup...";
        nextButtonText = "Picked Up";
        nextState = RideStatus.onroute;
        nextBackendStatus = 'onroute';
        break;
      case RideStatus.onroute:
        statusText = "On route to destination...";
        nextButtonText = "Complete Ride";
        nextState = RideStatus.finished;
        nextBackendStatus = null;
        break;
      case RideStatus.finished:
        statusText = "Ride Finished!";
        nextButtonText = "Finish";
        nextState = null;
        nextBackendStatus = null;
        break;
      default:
        statusText = "";
        nextButtonText = "";
        nextState = null;
        nextBackendStatus = null;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text("Ride Info", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _infoRow("Rider ID", request.riderId),
            _infoRow("Pickup", request.pickup),
            _infoRow("Destination", request.destination),
            _infoRow("Car Type", request.carType),
            _infoRow("Requested At", request.createdAt),
            const SizedBox(height: 16),
            Text(statusText, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            Row(
              children: [
                if (showRejectButton)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (request.objectId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Error: Ride request ID is missing')),
                          );
                          return;
                        }
                        await ref.read(driverServiceProvider).rejectRideRequest(
                              context: context,
                              objectId: request.objectId!,
                            );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Reject",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                if (showRejectButton) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (request.objectId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Error: Ride request ID is missing')),
                        );
                        return;
                      }
                      if (nextState == RideStatus.accepted) {
                        await ref.read(driverServiceProvider).acceptRideRequest(
                              context: context,
                              objectId: request.objectId!,
                              driverId: driverId,
                            );
                      } else if (nextState == RideStatus.finished) {
                        await ref.read(driverServiceProvider).completeRide(
                              context: context,
                              objectId: request.objectId!,
                            );
                        ref.read(driverServiceProvider)._clearRideState();
                      } else if (nextBackendStatus != null) {
                        await ref.read(driverServiceProvider).updateRideStatus(
                              context: context,
                              objectId: request.objectId!,
                              status: nextBackendStatus,
                            );
                        ref.read(rideStatusProvider.notifier).state =
                            nextState!;
                        if (nextState == RideStatus.start) {
                          mapController.move(
                              ref.read(pickupPositionProvider)!, 15.0);
                        }
                      } else if (nextState == null) {
                        ref.read(driverServiceProvider)._clearRideState();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: Text(
                      nextButtonText,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('driverObjectId');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GetStartedPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }
}

extension on DriverService {
  Future<void> completeRide({
    required BuildContext context,
    required String objectId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$back4appBaseUrl/classes/RideRequest/$objectId'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': 'finished',
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        print('Complete Ride Error: $errorBody');
        throw Exception(
            'Failed to complete ride: ${errorBody['error'] ?? 'Unknown error'} (Code: ${response.statusCode})');
      }
      print('Complete Ride Response: ${jsonDecode(response.body)}');
    } catch (e) {
      print('Error completing ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing ride: $e')),
      );
      rethrow;
    }
  }
}
