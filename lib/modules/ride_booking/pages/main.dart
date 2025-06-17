import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../model/ride_request_model.dart';
import 'discount_page.dart';
import '../../auth/pages/get_started_page.dart';
import 'order_history_page.dart';

// Constants
const String back4appBaseUrl = 'https://parseapi.back4app.com';
const String appId = "jU5yWVbYCi4B44T5SncVHDitWJhnzR1P9dKmo73y";
const String restApiKey = "hoH5efGxj37mG5fj3MQq2nDxXceK3VVsoW9csD5z";

// Riverpod Providers
final rideRequestServiceProvider = Provider<RideRequestService>((ref) {
  return RideRequestService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final fareProvider = StateProvider<Map<String, double>>((ref) => {});

final userPositionProvider = StateProvider<LatLng?>((ref) => null);
final destinationPositionProvider = StateProvider<LatLng?>((ref) => null);
final polylinePointsProvider = StateProvider<List<LatLng>>((ref) => []);

// Services
class RideRequestService {
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
          'objectId': riderId,
        },
      };
      print('RideRequest JSON Payload: $requestJson');

      final createResponse = await http.post(
        Uri.parse('$back4appBaseUrl/classes/RideRequest'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestJson),
      );

      if (createResponse.statusCode != 201) {
        final errorBody = jsonDecode(createResponse.body);
        print('Create Response Error: $errorBody');
        throw Exception(
            'Failed to create ride request: ${errorBody['error'] ?? 'Unknown error'} (Code: ${createResponse.statusCode})');
      }

      final createdObject = jsonDecode(createResponse.body);
      print('Create Response: $createdObject');
      final objectId = createdObject['objectId'];

      if (objectId == null || objectId is! String || objectId.isEmpty) {
        throw Exception(
            'Invalid or missing objectId in create response: $createdObject');
      }

      final assignJson = {
        'requestId': objectId,
        'carType': carType,
      };
      print('Assign Ride Request Payload: $assignJson');
      final assignResponse = await http.post(
        Uri.parse('$back4appBaseUrl/functions/assignRideRequest'),
        headers: {
          'X-Parse-Application-Id': appId,
          'X-Parse-REST-API-Key': restApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(assignJson),
      );

      if (assignResponse.statusCode != 200) {
        final errorBody = jsonDecode(assignResponse.body);
        print('Assign Response Error: $errorBody');
        throw Exception(
            'Failed to assign driver: ${errorBody['error'] ?? 'Unknown error'} (Code: ${assignResponse.statusCode})');
      }

      print('Assign Response: ${jsonDecode(assignResponse.body)}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride request submitted successfully')),
      );
    } catch (e) {
      print('Error submitting ride request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error submitting ride request: ${e.toString()}')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          pickupController.text = 'Permission denied';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        pickupController.text = 'Permission permanently denied';
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permission permanently denied')),
        );
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
      pickupController.text = 'Location unavailable';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e')),
      );
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
        double total = rate['base']! + (rate['perKm']! * distanceKm);
        fares[type] = total;
      });

      fareState.state = fares;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating fare: $e')),
      );
    }
  }
}

class RideRequestPage extends HookConsumerWidget {
  const RideRequestPage({super.key});

  Widget _buildSideNavBar(BuildContext context) {
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
                  backgroundImage: AssetImage('lib/shared/assets/user.png'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "John Doe",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _drawerItem(
                  context,
                  CupertinoIcons.time,
                  'Trip Orders',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const OrderHistoryPage()),
                  ),
                ),
                _drawerItem(
                  context,
                  CupertinoIcons.cart,
                  'Promotions',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DiscountPage()),
                  ),
                ),
                _drawerItem(
                  context,
                  CupertinoIcons.settings,
                  'Settings',
                  () {},
                ),
                _drawerItem(
                  context,
                  CupertinoIcons.question,
                  'Help',
                  () {},
                ),
                _drawerItem(
                  context,
                  CupertinoIcons.arrow_left_circle,
                  'Logout',
                  () => logout(context),
                ),
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  Future<void> logout(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userObjectId');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GetStartedPage()),
    );
  }

  Widget _iconContainer(IconData icon) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child:
          Center(child: Icon(icon, size: 28, color: const Color(0xFF555555))),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 245, 245, 245),
        borderRadius: BorderRadius.circular(10),
      ),
      child:
          Center(child: Icon(icon, size: 28, color: const Color(0xFF555555))),
    );
  }

  Widget _rotatedSwapIcon() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 245, 245, 245),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.arrow_up_arrow_down,
          color: Colors.grey,
          size: 28,
        ),
      ),
    );
  }

  Widget _locationInputRow(TextEditingController pickupController,
      TextEditingController destinationController) {
    return Column(
      children: [
        Row(
          children: [
            _iconBox(CupertinoIcons.location),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: pickupController,
                decoration: const InputDecoration(
                  labelText: 'Pickup',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            _rotatedSwapIcon(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _iconBox(CupertinoIcons.flag),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: destinationController,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  hintText: 'Enter destination',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAvailableCars({
    required BuildContext context,
    required WidgetRef ref,
    required String pickup,
    required String destination,
    required Map<String, double> fares,
  }) {
    final cars = [
      {
        'name': 'Economy',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/economy.png',
        'eta': '5-10 mins',
      },
      {
        'name': 'Basic',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/basic.png',
        'eta': '6-12 mins',
      },
      {
        'name': 'Executive',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/executive.png',
        'eta': '4-8 mins',
      },
      {
        'name': 'Minivan',
        'seats': '6 seats',
        'icon': 'lib/shared/assets/minivan.png',
        'eta': '10-15 mins',
      },
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Available Cars",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...cars.map((car) {
                final name = car['name']!;
                final fare = fares[name]?.toStringAsFixed(2) ?? '---';
                return ListTile(
                  leading: Image.asset(car['icon']!, width: 40),
                  title: Text(name),
                  subtitle: Text(
                      "${car['seats']} • ETA: ${car['eta']} • Estimated Fare: $fare Birr"),
                  onTap: () async {
                    Navigator.pop(context);
                    final userPosition = ref.read(userPositionProvider);
                    if (userPosition == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Pickup location not available')),
                      );
                      return;
                    }
                    await ref
                        .read(rideRequestServiceProvider)
                        .submitRideRequest(
                          context: context,
                          carType: name,
                          pickup: pickup,
                          destination: destination,
                          pickupPosition: userPosition,
                        );
                    _showSearchingBottomSheet(
                      context: context,
                      ref: ref,
                      pickup: pickup,
                      destination: destination,
                      carType: name,
                      fares: fares,
                    );
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showSearchingBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String pickup,
    required String destination,
    required String carType,
    required Map<String, double> fares,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return HookBuilder(
          builder: (context) {
            final step = useState('searching');
            final counter = useState(20);
            final totalFare = fares[carType]?.toStringAsFixed(2) ?? '---';

            useEffect(() {
              Timer.periodic(const Duration(seconds: 1), (timer) {
                if (counter.value == 0) {
                  timer.cancel();
                  final random = DateTime.now().millisecond % 2 == 0;
                  step.value = random ? 'accepted' : 'rejected';
                } else {
                  counter.value--;
                }
              });
              return null;
            }, []);

            switch (step.value) {
              case 'searching':
                return _buildStatusSheet(
                  context: context,
                  title: "Searching for a driver...",
                  icon: const CupertinoActivityIndicator(radius: 22),
                  subtitle: "Estimated wait time: ${counter.value} seconds",
                  cancelAction: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ride request cancelled')),
                    );
                  },
                );
              case 'rejected':
                return _buildStatusSheet(
                  context: context,
                  title: "No Drivers Available",
                  icon: const Icon(CupertinoIcons.exclamationmark_circle,
                      size: 44, color: Colors.red),
                  subtitle:
                      "No drivers found. Try again or select another car type.",
                  cancelAction: () {
                    Navigator.pop(context);
                    _showAvailableCars(
                      context: context,
                      ref: ref,
                      pickup: pickup,
                      destination: destination,
                      fares: fares,
                    );
                  },
                  cancelText: "Try Again",
                );
              case 'accepted':
                return _buildRideStatus(
                  title: "Driver Accepted",
                  subtitle: "Alex Johnson • 3 minutes away",
                  buttonText: "Start Ride",
                  onPressed: () => step.value = 'on_ride',
                  icon: const Icon(CupertinoIcons.checkmark_circle,
                      size: 44, color: Colors.green),
                );
              case 'on_ride':
                return _buildRideStatus(
                  title: "On Ride",
                  subtitle: "Enjoy your trip to $destination",
                  buttonText: "Finish Ride",
                  onPressed: () => step.value = 'completed',
                  icon: const Icon(CupertinoIcons.car_detailed,
                      size: 44, color: Color(0xFFFFA500)),
                );
              case 'completed':
                return _buildPaymentSheet(context, totalFare);
              default:
                return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildStatusSheet({
    required BuildContext context,
    required String title,
    required Widget icon,
    required String subtitle,
    VoidCallback? cancelAction,
    String? cancelText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(subtitle, textAlign: TextAlign.center),
          if (cancelAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: cancelAction,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  cancelText ?? "Cancel",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRideStatus({
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    required Widget icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const CircleAvatar(
              backgroundImage:
                  AssetImage('lib/shared/assets/driver_avatar.png'),
            ),
            title: const Text("Alex Johnson"),
            subtitle: Text(subtitle),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA500),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSheet(BuildContext context, String fare) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.checkmark_alt_circle,
              size: 44, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            "Ride Completed!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "Total Fare: $fare Birr",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            "Select Payment Method",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(CupertinoIcons.money_dollar),
            title: const Text("Cash"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Payment successful via Cash")),
              );
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.creditcard),
            title: const Text("Pay with Card"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Card payment option coming soon.")),
              );
            },
          ),
        ],
      ),
    );
  }

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
                        point.latitude,
                        point.longitude,
                      );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error geocoding location: $e')),
                      );
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 50.0,
                        height: 50.0,
                        point: userPosition,
                        builder: (ctx) => const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                      if (ref.watch(destinationPositionProvider) != null)
                        Marker(
                          width: 50.0,
                          height: 50.0,
                          point: ref.watch(destinationPositionProvider)!,
                          builder: (ctx) => const Icon(
                            Icons.flag,
                            color: Colors.blue,
                            size: 40.0,
                          ),
                        ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      if (ref.watch(polylinePointsProvider).isNotEmpty)
                        Polyline(
                          points: ref.watch(polylinePointsProvider),
                          strokeWidth: 4.0,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: _iconContainer(CupertinoIcons.bars),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Failed to get current location: $e')),
                        );
                      }
                    },
                    child: _iconContainer(CupertinoIcons.location),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _locationInputRow(pickupController, destinationController),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (destinationController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter a destination')),
                            );
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
                              ref.read(polylinePointsProvider.notifier).state =
                                  [ref.read(userPositionProvider)!, dest];
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
                              throw Exception(
                                  'No locations found for the provided address');
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Invalid destination: $e')),
                            );
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA500),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Search Car',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
