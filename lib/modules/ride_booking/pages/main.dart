import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../model/ride_request_model.dart';
import '../../auth/pages/get_started_page.dart';
import 'discount_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'order_history_page.dart';
import 'setting_page.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

// import 'package:app_settings/app_settings.dart';

// Constants
const String back4appBaseUrl = 'https://parseapi.back4app.com';
const String appId = "jU5yWVbYCi4B44T5SncVHDitWJhnzR1P9dKmo73y";
const String restApiKey = "hoH5efGxj37mG5fj3MQq2nDxXceK3VVsoW9csD5z";

// Enums
enum RideStatus { none, pending, accepted, start, onroute, finished }

// Ride History Model
class RideHistoryEntry {
  final String id;
  final String riderId;
  final String pickup;
  final String destination;
  final String carType;
  final double fare;
  final String status;
  final DateTime timestamp;

  RideHistoryEntry({
    required this.id,
    required this.riderId,
    required this.pickup,
    required this.destination,
    required this.carType,
    required this.fare,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'riderId': riderId,
        'pickup': pickup,
        'destination': destination,
        'carType': carType,
        'fare': fare,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RideHistoryEntry(
        id: json['id'],
        riderId: json['riderId'],
        pickup: json['pickup'],
        destination: json['destination'],
        carType: json['carType'],
        fare: json['fare'].toDouble(),
        status: json['status'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

// Styles
class RideRequestPageStyles {
  static const Color primaryColor = Color(0xFF37474F);
  static const Color secondaryColor = Colors.black87;
  static const Color backgroundColor = Colors.white;
  static const Color shadowColor = Colors.black12;
  static const Color errorColor = Colors.redAccent;

  static const TextStyle titleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: secondaryColor,
  );
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
    color: Colors.grey,
  );
  static const TextStyle buttonStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: backgroundColor,
  );
  static const TextStyle errorStyle = TextStyle(
    fontSize: 16,
    color: errorColor,
  );
  static const TextStyle countdownStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );
  static const double spacing = 16;
  static const double borderRadius = 12;
}

// Providers
final rideRequestServiceProvider =
    Provider<RideRequestService>((ref) => RideRequestService(ref));
final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
final fareProvider =
    StateProvider.autoDispose<Map<String, double>>((ref) => {});
final userPositionProvider = StateProvider.autoDispose<LatLng?>((ref) => null);
final destinationPositionProvider =
    StateProvider.autoDispose<LatLng?>((ref) => null);
final polylinePointsProvider =
    StateProvider.autoDispose<List<LatLng>>((ref) => []);
final rideStatusProvider =
    StateProvider.autoDispose<RideStatus>((ref) => RideStatus.none);
final currentRideRequestIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final driverDetailsProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

// Services
class RideRequestService {
  final Ref ref;

  RideRequestService(this.ref);

  Future<void> _saveRideHistory(RideHistoryEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyKey = 'ride_history_${entry.riderId}';
      final historyJson = prefs.getString(historyKey) ?? '[]';
      final List<dynamic> historyList = jsonDecode(historyJson);
      historyList.add(entry.toJson());
      await prefs.setString(historyKey, jsonEncode(historyList));
      print('Ride history saved successfully for riderId: ${entry.riderId}');
    } catch (e) {
      print(
          'Error saving ride history for riderId: ${entry.riderId}, Error: $e');
    }
  }

  Future<void> updateDriverRating(String driverObjectId, int newRating) async {
    print(
        'updateDriverRating called with driverObjectId: $driverObjectId, newRating: $newRating');

    try {
      // Fetch the current driver details to get the existing rating
      final driverDetails = await fetchDriverDetails(driverObjectId);
      if (driverDetails == null) {
        print('Failed to fetch driver details for rating update');
        throw Exception('Unable to fetch driver details');
      }

      // Get the existing rating (default to 0.0 if null)
      final existingRating = driverDetails['rating'] as double? ?? 0.0;
      print('Existing driver rating: $existingRating');

      // Calculate the new average rating
      final updatedRating = (existingRating + newRating) / 2.0;
      print('Calculated new average rating: $updatedRating');

      // Update the driver’s rating in the backend
      final driver = ParseObject('Driver')..objectId = driverObjectId;
      driver.set('rating', updatedRating);
      final response = await driver.save();
      if (response.success) {
        print('Driver rating updated successfully to: $updatedRating');
        // Update the driverDetailsProvider with the new rating
        ref.read(driverDetailsProvider.notifier).state = {
          ...driverDetails,
          'rating': updatedRating,
        };
      } else {
        print('Failed to update driver rating: ${response.error?.message}');
        throw Exception(
            'Failed to update driver rating: ${response.error?.message}');
      }
    } catch (e) {
      print('Error updating driver rating: $e');
      throw Exception('Error updating driver rating: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchDriverDetails(String driverId) async {
    try {
      final response = await http.get(
        Uri.parse('$back4appBaseUrl/classes/Driver/$driverId'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Driver Details Response: $data'); // Debug log
        final driverDetails = {
          'driverId': driverId,
          'name': data['name'] ?? data['username'] ?? 'Unknown Driver',
          'rating': double.tryParse(data['rating']?.toString() ?? '0.0') ?? 0.0,
        };
        print('Updating driverDetailsProvider with: $driverDetails');
        ref.read(driverDetailsProvider.notifier).state = driverDetails;
        return driverDetails;
      } else {
        print('Failed to fetch driver details: ${response.body}');
        throw Exception('Failed to fetch driver details: ${response.body}');
      }
    } catch (e) {
      print('Error fetching driver details: $e');
      ref.read(driverDetailsProvider.notifier).state = null;
      return null;
    }
  }

  Future<void> submitRideRequest({
    required BuildContext context,
    required String carType,
    required String pickup,
    required String destination,
    required LatLng pickupPosition,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final riderId = prefs.getString('userObjectId') ??
        'rider_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('userObjectId', riderId);

    final request = RideRequest(
      riderId: riderId,
      pickup: pickup,
      destination: destination,
      carType: carType,
      pickupLatitude: pickupPosition.latitude,
      pickupLongitude: pickupPosition.longitude,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      final requestJson = {
        ...request.toJson(),
        'status': 'pending',
        'riderId': {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': riderId
        },
      };

      print('Submitting Ride Request: $requestJson'); // Debug log
      final response = await http.post(
        Uri.parse('$back4appBaseUrl/classes/RideRequest'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestJson),
      );

      if (response.statusCode != 201) {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        print('Failed to create ride request: $error');
        throw Exception('Failed to create ride request: $error');
      }

      final objectId = jsonDecode(response.body)['objectId'] as String?;
      if (objectId == null || objectId.isEmpty) {
        throw Exception('Invalid objectId');
      }

      print('Ride Request Created: objectId=$objectId');
      ref.read(currentRideRequestIdProvider.notifier).state = objectId;
      ref.read(rideStatusProvider.notifier).state = RideStatus.pending;

      final assignResponse = await http.post(
        Uri.parse('$back4appBaseUrl/functions/assignRideRequest'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'requestId': objectId, 'carType': carType}),
      );

      if (assignResponse.statusCode != 200) {
        final error =
            jsonDecode(assignResponse.body)['error'] ?? 'Unknown error';
        print('Failed to assign driver: $error');
        throw Exception('Failed to assign driver: $error');
      }

      final assignResult = jsonDecode(assignResponse.body);
      print('Assign Ride Response: $assignResult'); // Debug log
      if (assignResult['result']?['driverId'] != null) {
        final driverDetails =
            await fetchDriverDetails(assignResult['result']['driverId']);
        ref.read(driverDetailsProvider.notifier).state = driverDetails;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride request submitted')));
      }
    } catch (e) {
      ref.read(currentRideRequestIdProvider.notifier).state = null;
      ref.read(rideStatusProvider.notifier).state = RideStatus.none;
      ref.read(driverDetailsProvider.notifier).state = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Error: $e', style: RideRequestPageStyles.errorStyle)));
      }
      rethrow;
    }
  }

  Future<void> pollRideStatus({
    required BuildContext context,
    required String requestId,
    int retryCount = 0,
  }) async {
    const maxRetries = 3;
    try {
      final response = await http.get(
        Uri.parse(
            '$back4appBaseUrl/classes/RideRequest?where=${Uri.encodeComponent(jsonEncode({
              "objectId": requestId
            }))}&include=assignedDriverId'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Poll Ride Status Response: $data'); // Debug log
        if (data['results']?.isNotEmpty == true) {
          final result = data['results'][0];
          final status = result['status'];
          final driverPointer = result['assignedDriverId'];
          final newStatus = {
                'pending': RideStatus.pending,
                'assigned': RideStatus.pending,
                'accepted': RideStatus.accepted,
                'start': RideStatus.start,
                'onroute': RideStatus.onroute,
                'finished': RideStatus.finished,
                'rejected': RideStatus.none,
                'cancelled': RideStatus.none,
              }[status] ??
              RideStatus.none;

          ref.read(rideStatusProvider.notifier).state = newStatus;

          if (driverPointer != null && driverPointer['objectId'] != null) {
            print('Driver Pointer: $driverPointer'); // Debug log
            if (driverPointer['className'] != 'Driver') {
              print(
                  'Warning: assignedDriverId points to ${driverPointer['className']} instead of Driver');
            }
            final driverDetails =
                await fetchDriverDetails(driverPointer['objectId']);
            print('Updating driverDetailsProvider with: $driverDetails');
            ref.read(driverDetailsProvider.notifier).state = driverDetails;
          } else if (newStatus == RideStatus.none) {
            ref.read(driverDetailsProvider.notifier).state = null;
          }

          if (newStatus == RideStatus.none) {
            ref.read(currentRideRequestIdProvider.notifier).state = null;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(status == 'rejected'
                      ? 'Ride rejected by driver'
                      : 'Ride cancelled')));
            }
          }
        } else {
          print('No ride request found for objectId: $requestId');
          ref.read(rideStatusProvider.notifier).state = RideStatus.none;
          ref.read(currentRideRequestIdProvider.notifier).state = null;
          ref.read(driverDetailsProvider.notifier).state = null;
        }
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        print('Polling failed: $error');
        throw Exception('Polling failed: $error');
      }
    } catch (e) {
      print('Error polling ride status: $e');
      if (retryCount < maxRetries) {
        await Future.delayed(const Duration(seconds: 1));
        return pollRideStatus(
            context: context, requestId: requestId, retryCount: retryCount + 1);
      }
      ref.read(rideStatusProvider.notifier).state = RideStatus.none;
      ref.read(currentRideRequestIdProvider.notifier).state = null;
      ref.read(driverDetailsProvider.notifier).state = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Status update failed: $e',
                style: RideRequestPageStyles.errorStyle)));
      }
    }
  }

  Future<void> cancelRideRequest({
    required BuildContext context,
    required String objectId,
  }) async {
    try {
      print('Cancelling Ride Request: objectId=$objectId'); // Debug log
      final response = await http.put(
        Uri.parse('$back4appBaseUrl/classes/RideRequest/$objectId'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': 'cancelled'}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
        print('Failed to cancel ride: $error');
        throw Exception('Failed to cancel ride: $error');
      }

      print('Ride cancelled successfully');
      ref.read(rideStatusProvider.notifier).state = RideStatus.none;
      ref.read(currentRideRequestIdProvider.notifier).state = null;
      ref.read(driverDetailsProvider.notifier).state = null;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ride cancelled')));
      }
    } catch (e) {
      print('Error cancelling ride: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error cancelling ride: $e',
                style: RideRequestPageStyles.errorStyle)));
      }
      rethrow;
    }
  }
}

class LocationService {
  Future<void> fetchCurrentLocation({
    required BuildContext context,
    required TextEditingController pickupController,
    required StateController<LatLng?> userPosition,
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        pickupController.text = 'Location service disabled';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enable location services')));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          pickupController.text = 'Permission denied';
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location permission denied')));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        pickupController.text = 'Permission permanently denied';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission permanently denied')));
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      userPosition.state = LatLng(position.latitude, position.longitude);

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      final place = placemarks.first;
      pickupController.text =
          '${place.street}, ${place.locality}, ${place.country}';
    } catch (e) {
      print('Error fetching location: $e'); // Debug log
      pickupController.text = 'Location unavailable';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error fetching location: $e',
                style: RideRequestPageStyles.errorStyle)));
      }
    }
  }

  Future<void> calculateEstimatedFare({
    required BuildContext context,
    required StateController<LatLng?> userPosition,
    required StateController<LatLng?> destinationPosition,
    required StateController<Map<String, double>> fareState,
  }) async {
    if (userPosition.state == null || destinationPosition.state == null) return;

    try {
      double distanceMeters = Geolocator.distanceBetween(
        userPosition.state!.latitude,
        userPosition.state!.longitude,
        destinationPosition.state!.latitude,
        destinationPosition.state!.longitude,
      );
      double distanceKm = distanceMeters / 1000.0;

      final fareRates = {
        'Economy': {'base': 120.0, 'perKm': 10.0},
        'Basic': {'base': 140.0, 'perKm': 12.0},
        'Executive': {'base': 180.0, 'perKm': 15.0},
        'Minivan': {'base': 200.0, 'perKm': 18.0},
      };

      final fares = <String, double>{};
      fareRates.forEach((type, rate) {
        fares[type] = rate['base']! + (rate['perKm']! * distanceKm);
      });

      fareState.state = fares;
      print('Calculated Fares: $fares'); // Debug log
    } catch (e) {
      print('Error calculating fare: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error calculating fare: $e',
                style: RideRequestPageStyles.errorStyle)));
      }
    }
  }
}

// UI Components
class RideRequestPage extends HookConsumerWidget {
  const RideRequestPage({super.key});

  static const Map<RideStatus, Map<String, dynamic>> statusConfig = {
    RideStatus.pending: {
      'title': 'Searching for a Driver...',
      'subtitle': 'Finding the best driver for your ride.',
      'icon':
          CircularProgressIndicator(color: RideRequestPageStyles.primaryColor),
      'showCancel': true,
    },
    RideStatus.accepted: {
      'title': 'Driver Accepted',
      'subtitle': 'Your driver is preparing to head to your pickup location: ',
      'icon':
          Icon(CupertinoIcons.checkmark_circle, size: 48, color: Colors.green),
      'showCancel': false,
    },
    RideStatus.start: {
      'title': 'Driver Heading to Pickup',
      'subtitle': 'Your driver is on the way to your pickup location: ',
      'icon': Icon(CupertinoIcons.car_detailed,
          size: 48, color: RideRequestPageStyles.primaryColor),
      'showCancel': false,
    },
    RideStatus.onroute: {
      'title': 'On Route to Destination',
      'subtitle': 'Your driver is heading to your destination: ',
      'icon': Icon(CupertinoIcons.car_detailed,
          size: 48, color: RideRequestPageStyles.primaryColor),
      'showCancel': false,
    },
    RideStatus.finished: {
      'title': 'Ride Completed!',
      'subtitle': 'Thank you for riding with us!',
      'icon': Icon(CupertinoIcons.checkmark_alt_circle,
          size: 48, color: Colors.green),
      'showCancel': false,
    },
  };

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) =>
      SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            gradient: backgroundColor == null
                ? const LinearGradient(
                    colors: [
                      Color(0xFF34A853), // Warm Green
                      Color(0xFF34A853), // Orange-Red
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: backgroundColor, // Fallback if backgroundColor is passed
            borderRadius:
                BorderRadius.circular(RideRequestPageStyles.borderRadius),
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(
                  vertical: RideRequestPageStyles.spacing),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(RideRequestPageStyles.borderRadius),
              ),
            ),
            child: Text(label, style: RideRequestPageStyles.buttonStyle),
          ),
        ),
      );

  Drawer _buildSideNavBar(BuildContext context) => Drawer(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(RideRequestPageStyles.borderRadius),
            bottomRight: Radius.circular(RideRequestPageStyles.borderRadius),
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final prefs = snapshot.data!;
              final userName = prefs.getString('userName') ?? 'User';
              final userPhoneNumber =
                  prefs.getString('userPhoneNumber') ?? 'No phone number';

              return Column(
                children: [
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF21201E)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RiderSettingsPage(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                AssetImage('lib/shared/assets/user.png'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style:
                                      RideRequestPageStyles.titleStyle.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF21201E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userPhoneNumber,
                                  style: RideRequestPageStyles.subtitleStyle
                                      .copyWith(
                                    color: const Color(0xFF21201E)
                                        .withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _buildGroup([
                          _buildDrawerItem(context, CupertinoIcons.bell,
                              'Enable notifications', () => {}),
                          _buildDrawerItem(
                              context, CupertinoIcons.gift, 'Discounts & gifts',
                              () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DiscountPage(),
                              ),
                            );
                          }),
                        ]),
                        _buildGroup([
                          _buildDrawerItem(
                              context, CupertinoIcons.time, 'History', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const OrderHistoryPage(),
                              ),
                            );
                          }),
                          _buildDrawerItem(context, CupertinoIcons.phone,
                              'Call Center', () => _callPhone(context)),
                          _buildDrawerItem(context, CupertinoIcons.info_circle,
                              'About Us', () => _openWebsite(context)),
                        ]),
                        _buildGroup([
                          _buildDrawerItem(
                              context,
                              CupertinoIcons.square_arrow_right,
                              'Logout',
                              () => _logout(context)),
                        ]),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Text(
                      "© All rights reserved",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
// Drawer item
  Widget _buildDrawerItem(BuildContext context, IconData icon, String title,
          VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: const Color(0xFF21201E)),
        title: Text(
          title,
          style: RideRequestPageStyles.subtitleStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF21201E),
          ),
        ),
        onTap: onTap,
      );

// Group wrapper with background
  Widget _buildGroup(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F4F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      );

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userObjectId');
    await prefs.remove('userName');
    await prefs.remove('userPhoneNumber');
    if (context.mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const GetStartedPage()));
    }
  }

  Future<void> _callPhone(BuildContext context) async {
    String number = "0929175653";
    final Uri uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // Future<void> _openLocationSettings() async {
  //   AppSettings.openLocationSettings();
  // }

  // Future<void> _openNotSettings() async {
  //   AppSettings.openNotificationSettings();
  // }

  Future<void> _openWebsite(BuildContext) async {
    String url = "https://google.com";
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildIconContainer(IconData icon) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: RideRequestPageStyles.backgroundColor,
          borderRadius:
              BorderRadius.circular(RideRequestPageStyles.borderRadius),
          boxShadow: const [
            BoxShadow(
                color: RideRequestPageStyles.shadowColor,
                blurRadius: 4,
                offset: Offset(0, 2))
          ],
        ),
        child: Center(
            child: Icon(icon,
                size: 24, color: RideRequestPageStyles.primaryColor)),
      );

  Widget _buildIconBox(IconData icon) => Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius:
              BorderRadius.circular(RideRequestPageStyles.borderRadius),
        ),
        child: Center(
            child: Icon(icon,
                size: 22, color: const Color.fromARGB(255, 74, 76, 79))),
      );

  Widget _buildRotatedSwapIcon() => Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius:
              BorderRadius.circular(RideRequestPageStyles.borderRadius),
        ),
        child: const Center(
            child: Icon(CupertinoIcons.arrow_up_arrow_down,
                color: Colors.blueGrey, size: 22)),
      );

  Widget _buildLocationInputRow(TextEditingController pickupController,
          TextEditingController destinationController) =>
      Column(
        children: [
          Row(
            children: [
              _buildIconBox(CupertinoIcons.location),
              const SizedBox(width: RideRequestPageStyles.spacing),
              Expanded(
                child: TextField(
                  controller: pickupController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelText: 'Pickup',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          RideRequestPageStyles.borderRadius),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              _buildRotatedSwapIcon(),
            ],
          ),
          const SizedBox(height: RideRequestPageStyles.spacing),
          Row(
            children: [
              _buildIconBox(CupertinoIcons.flag),
              const SizedBox(width: RideRequestPageStyles.spacing),
              Expanded(
                child: TextField(
                  controller: destinationController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelText: 'Destination',
                    hintText: 'Enter destination',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          RideRequestPageStyles.borderRadius),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
  void _showRatingDialog(BuildContext context, String? driverObjectId) {
    showDialog(
      context: context,
      builder: (context) {
        final rating = ValueNotifier<int?>(null);
        return Consumer(
          builder: (context, ref, _) {
            final driverDetails = ref.watch(driverDetailsProvider);
            final effectiveDriverId =
                driverObjectId ?? driverDetails?['driverId'] as String?;
            print(
                'Rating Dialog - Driver Details: $driverDetails, Effective Driver ID: $effectiveDriverId');
            return AlertDialog(
              backgroundColor: const Color(0xFFF5F4F2),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(RideRequestPageStyles.borderRadius),
              ),
              title: Row(
                children: [
                  Image.asset(
                    'lib/shared/assets/rate.png',
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(CupertinoIcons.star, size: 40),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Rate Your Ride",
                    style: RideRequestPageStyles.titleStyle.copyWith(
                      color: const Color(0xFF21201E),
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "How was your experience?",
                    style: RideRequestPageStyles.subtitleStyle.copyWith(
                      color: const Color(0xFF21201E).withOpacity(0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => ValueListenableBuilder<int?>(
                        valueListenable: rating,
                        builder: (context, value, child) => IconButton(
                          icon: Icon(
                            index < (value ?? 0)
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.star,
                            color: index < (value ?? 0)
                                ? const Color(0xFF21201E)
                                : Colors.grey,
                            size: 32,
                          ),
                          onPressed: () => rating.value = index + 1,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int?>(
                    valueListenable: rating,
                    builder: (context, value, child) => value != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "Rated $value star${value == 1 ? '' : 's'}!",
                              style:
                                  RideRequestPageStyles.subtitleStyle.copyWith(
                                color: const Color(0xFF21201E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF21201E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    print('Rating dialog Done button pressed');
                    final selectedRating = rating.value ?? 0;
                    print('Selected rating: $selectedRating');
                    print('Driver objectId: $effectiveDriverId');
                    if (selectedRating > 0 && effectiveDriverId != null) {
                      print(
                          'Submitting rating $selectedRating for driver $effectiveDriverId');
                      await ref
                          .read(rideRequestServiceProvider)
                          .updateDriverRating(
                              effectiveDriverId, selectedRating);
                      ref.read(driverDetailsProvider.notifier).state = null;
                      ref.read(currentRideRequestIdProvider.notifier).state =
                          null;
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rating submitted!')),
                        );
                      }
                    } else {
                      print(
                          'Rating not submitted: selectedRating=$selectedRating, driverObjectId=$effectiveDriverId');
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to submit rating: No driver selected or invalid rating',
                              style: RideRequestPageStyles.errorStyle,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

// ...existing code...
  void _showAvailableCars({
    required BuildContext context,
    required WidgetRef ref,
    required String pickup,
    required String destination,
    required Map<String, double> fares,
  }) {
    final promoController = TextEditingController();
    DiscountCode? appliedDiscount;
    Future<DiscountCode?> _validatePromoCode(String code) async {
      final query = QueryBuilder<ParseObject>(ParseObject('DiscountCode'))
        ..whereEqualTo('code', code.trim());

      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        return DiscountCode.fromParse(response.results!.first as ParseObject);
      }
      return null;
    }

    Map<String, double> _applyDiscount(
        Map<String, double> fares, DiscountCode discount) {
      final factor = (100 - discount.amount) / 100.0;
      return fares.map((key, value) => MapEntry(key, value * factor));
    }

    final cars = [
      {
        'name': 'Economy',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/economy.png',
        'eta': '5-10 mins',
        'etaSeconds': 480, // Average of 8 minutes
      },
      {
        'name': 'Basic',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/basic.png',
        'eta': '6-12 mins',
        'etaSeconds': 540, // Average of 9 minutes
      },
      {
        'name': 'Executive',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/executive.png',
        'eta': '4-8 mins',
        'etaSeconds': 360, // Average of 6 minutes
      },
      {
        'name': 'Minivan',
        'seats': '6 seats',
        'icon': 'lib/shared/assets/minivan.png',
        'eta': '10-15 mins',
        'etaSeconds': 750, // Average of 12.5 minutes
      },
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(RideRequestPageStyles.borderRadius))),
      builder: (bottomSheetContext) => Padding(
        padding: const EdgeInsets.all(RideRequestPageStyles.spacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Available Cars", style: RideRequestPageStyles.titleStyle),
            const SizedBox(height: RideRequestPageStyles.spacing),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: promoController,
                    decoration: InputDecoration(
                      hintText: 'Enter Promo Code',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          RideRequestPageStyles.borderRadius,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade300,
                        Colors.grey.shade400,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      RideRequestPageStyles.borderRadius,
                    ),
                  ),
                  child: TextButton(
                    onPressed: () async {
                      final code = promoController.text.trim();
                      if (code.isEmpty) return;

                      final discount = await _validatePromoCode(code);

                      if (discount != null) {
                        appliedDiscount = discount;
                        fares = _applyDiscount(fares, discount);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Promo applied: ${discount.title} - ${discount.amount}% off'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid promo code'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RideRequestPageStyles.borderRadius,
                        ),
                      ),
                    ),
                    child: const Text("Apply"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RideRequestPageStyles.spacing),
            ...cars.map((car) {
              final name = car['name'] as String; // Explicit cast to String
              final fare = fares[name]?.toStringAsFixed(2) ?? '---';
              final iconPath = car['icon'] as String; // Explicit cast to String
              return ListTile(
                leading: Image.asset(iconPath, width: 40),
                title: Text(name,
                    style: RideRequestPageStyles.titleStyle
                        .copyWith(fontSize: 18)),
                subtitle: Text(
                    "${car['seats']} • ETA: ${car['eta']} • Fare: $fare Birr",
                    style: RideRequestPageStyles.subtitleStyle),
                onTap: () async {
                  Navigator.pop(
                      bottomSheetContext); // Close car selection sheet
                  final userPosition = ref.read(userPositionProvider);
                  if (userPosition == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Pickup location unavailable')));
                    }
                    return;
                  }
                  try {
                    await ref
                        .read(rideRequestServiceProvider)
                        .submitRideRequest(
                          context: context,
                          carType: name, // Ensure name is a String
                          pickup: pickup,
                          destination: destination,
                          pickupPosition: userPosition,
                        );
                    if (context.mounted) {
                      _showSearchingBottomSheet(
                        context: context,
                        ref: ref,
                        pickup: pickup,
                        destination: destination,
                        carType: name,
                        fares: fares,
                        etaSeconds: car['etaSeconds'] as int,
                      );
                    }
                  } catch (e) {
                    // Error handled in submitRideRequest
                    print('Error submitting ride request: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e',
                              style: RideRequestPageStyles.errorStyle)));
                    }
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSearchingBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String pickup,
    required String destination,
    required String? carType,
    required Map<String, double> fares,
    required int etaSeconds,
  }) {
    if (carType == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Car type not selected',
                style: RideRequestPageStyles.errorStyle)));
      }
      return;
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(RideRequestPageStyles.borderRadius))),
        builder: (context) => StatusBottomSheet(
          ref: ref,
          pickup: pickup,
          destination: destination,
          carType: carType,
          fares: fares,
          etaSeconds: etaSeconds,
        ),
      );
    }
  }

  Widget _buildStatusSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required Widget icon,
    required String subtitle,
    required bool showCancel,
    required RideStatus rideStatus,
    String? requestId,
    String? carType,
    String? pickup,
    String? destination,
    int? etaSeconds,
  }) {
    final etaCountdown = useState(etaSeconds ?? 0);

    useEffect(() {
      if (etaSeconds != null && etaCountdown.value > 0) {
        Timer? timer;
        timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (etaCountdown.value > 0) {
            etaCountdown.value--;
          } else {
            timer.cancel();
          }
        });
        return timer.cancel;
      }
      return null;
    }, [etaSeconds]);

    String formatDuration(int seconds) {
      if (seconds <= 0) return '00:00';
      final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
      final secs = (seconds % 60).toString().padLeft(2, '0');
      return '$minutes:$secs';
    }

    return Padding(
      padding: const EdgeInsets.all(RideRequestPageStyles.spacing),
      child: Consumer(
        builder: (context, ref, child) {
          final driverDetails = ref.watch(driverDetailsProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: RideRequestPageStyles.spacing),
              Text(title,
                  style: RideRequestPageStyles.titleStyle,
                  textAlign: TextAlign.center),
              const SizedBox(height: RideRequestPageStyles.spacing / 2),
              Text(
                  subtitle +
                      (rideStatus == RideStatus.accepted ||
                              rideStatus == RideStatus.start
                          ? (pickup ?? 'Unknown location')
                          : (destination ?? 'Unknown destination')),
                  style: RideRequestPageStyles.subtitleStyle,
                  textAlign: TextAlign.center),
              if (driverDetails != null &&
                  rideStatus != RideStatus.pending) ...[
                const SizedBox(height: RideRequestPageStyles.spacing),
                ListTile(
                  leading: const CircleAvatar(
                      radius: 30,
                      backgroundImage:
                          AssetImage('lib/shared/assets/driver.png')),
                  title: Text(driverDetails['name'] ?? 'Unknown Driver',
                      style: RideRequestPageStyles.titleStyle
                          .copyWith(fontSize: 18)),
                  subtitle: Text(
                      "$carType • ${driverDetails['rating']?.toStringAsFixed(1) ?? 'N/A'} ★",
                      style: RideRequestPageStyles.subtitleStyle),
                ),
                if (rideStatus == RideStatus.accepted ||
                    rideStatus == RideStatus.start ||
                    rideStatus == RideStatus.onroute) ...[
                  const SizedBox(height: RideRequestPageStyles.spacing / 2),
                  Text(
                    'Estimated Arrival: ${formatDuration(etaCountdown.value)}',
                    style: RideRequestPageStyles.countdownStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
              if (showCancel && requestId != null) ...[
                const SizedBox(height: RideRequestPageStyles.spacing),
                _buildPrimaryButton(
                  label: 'Cancel Ride',
                  backgroundColor: RideRequestPageStyles.errorColor,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Cancel Ride?"),
                      content: const Text(
                          "Are you sure you want to cancel this ride request?"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("No")),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close dialog
                            await ref
                                .read(rideRequestServiceProvider)
                                .cancelRideRequest(
                                    context: context, objectId: requestId);
                            if (context.mounted) {
                              Navigator.pop(context); // Close bottom sheet
                            }
                          },
                          child: const Text("Yes",
                              style: TextStyle(
                                  color: RideRequestPageStyles.errorColor)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!showCancel &&
                  driverDetails != null &&
                  carType != null &&
                  rideStatus != RideStatus.finished) ...[
                const SizedBox(height: RideRequestPageStyles.spacing),
                _buildPrimaryButton(
                  label: 'Contact Driver',
                  onPressed: () {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Contacting driver...")));
                    }
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentSheet(
    BuildContext context,
    String fare, {
    required String pickup,
    required String destination,
    required String carType,
  }) =>
      HookConsumer(
        builder: (context, ref, child) {
          final requestId = ref.read(currentRideRequestIdProvider);
          final driverDetails = ref.read(driverDetailsProvider);
          final driverObjectId = driverDetails?['driverId'] as String?;

          Future<void> saveHistory() async {
            final prefs = await SharedPreferences.getInstance();
            final riderId = prefs.getString('userObjectId') ?? '';
            final entry = RideHistoryEntry(
              id: requestId ?? '',
              riderId: riderId,
              pickup: pickup,
              destination: destination,
              carType: carType,
              fare: double.tryParse(fare) ?? 0.0,
              status: 'finished',
              timestamp: DateTime.now().toUtc(),
            );
            await ref.read(rideRequestServiceProvider)._saveRideHistory(entry);
          }

          return Padding(
            padding: const EdgeInsets.all(RideRequestPageStyles.spacing),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ListTile(
                  leading: const Icon(CupertinoIcons.money_dollar,
                      color: RideRequestPageStyles.primaryColor),
                  title: Text("Cash",
                      style: RideRequestPageStyles.titleStyle
                          .copyWith(fontSize: 18)),
                  onTap: () async {
                    await saveHistory(); // Save history first
                    Navigator.pop(context); // Close payment sheet
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Payment successful via Cash")));
                      _showRatingDialog(
                          context, driverObjectId); // Pass driverObjectId
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.creditcard,
                      color: RideRequestPageStyles.primaryColor),
                  title: Text("Pay with Card",
                      style: RideRequestPageStyles.titleStyle
                          .copyWith(fontSize: 18)),
                  onTap: () async {
                    await saveHistory(); // Save history first
                    Navigator.pop(context); // Close payment sheet
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Card payment coming soon")));
                      _showRatingDialog(
                          context, driverObjectId); // Pass driverObjectId
                    }
                  },
                ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupController =
        useTextEditingController(text: 'Fetching location...');
    final destinationController = useTextEditingController();
    final mapController = useMemoized(() => MapController(), []);

    useEffect(() {
      ref.read(locationServiceProvider).fetchCurrentLocation(
            context: context,
            pickupController: pickupController,
            userPosition: ref.read(userPositionProvider.notifier),
          );
      return null;
    }, []);

    useEffect(() {
      final requestId = ref.watch(currentRideRequestIdProvider);
      Timer? timer;
      if (requestId != null) {
        timer = Timer.periodic(const Duration(seconds: 3), (_) async {
          await ref
              .read(rideRequestServiceProvider)
              .pollRideStatus(context: context, requestId: requestId);
        });
      }
      return () => timer?.cancel();
    }, [ref.watch(currentRideRequestIdProvider)]);

    return Scaffold(
      drawer: _buildSideNavBar(context),
      body: Stack(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final userPosition = ref.watch(userPositionProvider);
              if (userPosition == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center: userPosition,
                  zoom: 15.0,
                  onTap: (tapPosition, point) async {
                    try {
                      final placemarks = await placemarkFromCoordinates(
                          point.latitude, point.longitude);
                      final place = placemarks.first;
                      destinationController.text =
                          '${place.street}, ${place.locality}, ${place.country}';
                      ref.read(destinationPositionProvider.notifier).state =
                          point;
                      ref.read(polylinePointsProvider.notifier).state = [
                        userPosition,
                        point
                      ];
                      await ref
                          .read(locationServiceProvider)
                          .calculateEstimatedFare(
                            context: context,
                            userPosition:
                                ref.read(userPositionProvider.notifier),
                            destinationPosition:
                                ref.read(destinationPositionProvider.notifier),
                            fareState: ref.read(fareProvider.notifier),
                          );
                    } catch (e) {
                      destinationController.text = 'Unknown location';
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Geocoding error: $e',
                                  style: RideRequestPageStyles.errorStyle)),
                        );
                      }
                    }
                  },
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
                        width: 50.0,
                        height: 50.0,
                        point: userPosition,
                        builder: (ctx) => const Icon(
                            CupertinoIcons.location_fill,
                            color: Colors.red,
                            size: 40.0),
                      ),
                      if (ref.watch(destinationPositionProvider) != null)
                        Marker(
                          width: 50.0,
                          height: 50.0,
                          point: ref.watch(destinationPositionProvider)!,
                          builder: (ctx) => const Icon(CupertinoIcons.flag_fill,
                              color: Colors.blue, size: 40.0),
                        ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      if (ref.watch(polylinePointsProvider).isNotEmpty)
                        Polyline(
                            points: ref.watch(polylinePointsProvider),
                            strokeWidth: 4.0,
                            color: Colors.blue),
                    ],
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: RideRequestPageStyles.spacing,
                  vertical: RideRequestPageStyles.spacing / 2),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: _buildIconContainer(CupertinoIcons.bars),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final position = await Geolocator.getCurrentPosition();
                        final currentLatLng =
                            LatLng(position.latitude, position.longitude);
                        mapController.move(currentLatLng, 15.0);
                        ref.read(userPositionProvider.notifier).state =
                            currentLatLng;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Location error: $e',
                                    style: RideRequestPageStyles.errorStyle)),
                          );
                        }
                      }
                    },
                    child: _buildIconContainer(CupertinoIcons.location),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(RideRequestPageStyles.spacing),
              child: Container(
                padding: const EdgeInsets.all(RideRequestPageStyles.spacing),
                decoration: BoxDecoration(
                  color: RideRequestPageStyles.backgroundColor,
                  borderRadius:
                      BorderRadius.circular(RideRequestPageStyles.borderRadius),
                  boxShadow: const [
                    BoxShadow(
                        color: RideRequestPageStyles.shadowColor,
                        blurRadius: 8,
                        offset: Offset(0, 2))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLocationInputRow(
                        pickupController, destinationController),
                    const SizedBox(height: RideRequestPageStyles.spacing),
                    _buildPrimaryButton(
                      label: 'Search Car',
                      onPressed: () async {
                        if (destinationController.text.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter a destination',
                                      style: RideRequestPageStyles.errorStyle)),
                            );
                          }
                          return;
                        }

                        try {
                          final locations = await locationFromAddress(
                              destinationController.text);
                          if (locations.isNotEmpty) {
                            final dest = LatLng(locations.first.latitude,
                                locations.first.longitude);
                            ref
                                .read(destinationPositionProvider.notifier)
                                .state = dest;
                            ref.read(polylinePointsProvider.notifier).state = [
                              ref.read(userPositionProvider)!,
                              dest
                            ];
                            await ref
                                .read(locationServiceProvider)
                                .calculateEstimatedFare(
                                  context: context,
                                  userPosition:
                                      ref.read(userPositionProvider.notifier),
                                  destinationPosition: ref.read(
                                      destinationPositionProvider.notifier),
                                  fareState: ref.read(fareProvider.notifier),
                                );
                          } else {
                            throw Exception('No locations found');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Invalid destination: $e',
                                      style: RideRequestPageStyles.errorStyle)),
                            );
                          }
                          return;
                        }

                        _showAvailableCars(
                          context: context,
                          ref: ref,
                          pickup: pickupController.text,
                          destination: destinationController.text,
                          fares: ref.read(fareProvider),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Status Bottom Sheet
// ...existing code...

class StatusBottomSheet extends HookConsumerWidget {
  final WidgetRef ref;
  final String pickup;
  final String destination;
  final String carType;
  final Map<String, double> fares;
  final int etaSeconds;

  const StatusBottomSheet({
    super.key,
    required this.ref,
    required this.pickup,
    required this.destination,
    required this.carType,
    required this.fares,
    required this.etaSeconds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideStatus = ref.watch(rideStatusProvider);
    final requestId = ref.watch(currentRideRequestIdProvider);
    final totalFare = fares[carType]?.toStringAsFixed(2) ?? '---';

    final uniqueKey = '${rideStatus.toString()}_${requestId ?? 'no_id'}';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
      child: Container(
        key: ValueKey<String>(uniqueKey),
        child: rideStatus == RideStatus.none
            ? _buildErrorSheet(context)
            : rideStatus == RideStatus.finished
                ? RideRequestPage()._buildPaymentSheet(
                    context,
                    totalFare,
                    pickup: pickup,
                    destination: destination,
                    carType: carType,
                  )
                : RideRequestPage()._buildStatusSheet(
                    context: context,
                    ref: ref,
                    title: RideRequestPage.statusConfig[rideStatus]!['title']
                        as String,
                    icon: RideRequestPage.statusConfig[rideStatus]!['icon']
                        as Widget,
                    subtitle: RideRequestPage
                        .statusConfig[rideStatus]!['subtitle'] as String,
                    showCancel: RideRequestPage
                        .statusConfig[rideStatus]!['showCancel'] as bool,
                    rideStatus: rideStatus,
                    requestId: requestId,
                    carType: carType,
                    pickup: pickup,
                    destination: destination,
                    etaSeconds: etaSeconds,
                  ),
      ),
    );
  }

  Widget _buildErrorSheet(BuildContext context) => Padding(
        padding: const EdgeInsets.all(RideRequestPageStyles.spacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle,
                size: 48, color: RideRequestPageStyles.errorColor),
            const SizedBox(height: RideRequestPageStyles.spacing),
            Text('Ride Status Unavailable',
                style: RideRequestPageStyles.titleStyle,
                textAlign: TextAlign.center),
            const SizedBox(height: RideRequestPageStyles.spacing / 2),
            Text('Unable to fetch status. Try again.',
                style: RideRequestPageStyles.subtitleStyle,
                textAlign: TextAlign.center),
            const SizedBox(height: RideRequestPageStyles.spacing),
            RideRequestPage()._buildPrimaryButton(
              label: 'Close',
              onPressed: () => Navigator.pop(context),
              backgroundColor: RideRequestPageStyles.errorColor,
            ),
          ],
        ),
      );
}

// ...existing code...
