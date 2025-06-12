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
import '../../driver_console/models/ride_request_model.dart';
import 'discount_page.dart';
import '../../auth/pages/get_started_page.dart';
import 'order_history_page.dart';

const String back4appBaseUrl = 'https://parseapi.back4app.com';
const String appId = "jU5yWVbYCi4B44T5SncVHDitWJhnzR1P9dKmo73y";
const String restApiKey = "hoH5efGxj37mG5fj3MQq2nDxXceK3VVsoW9csD5z";

class RideRequestPage extends HookConsumerWidget {
  const RideRequestPage({super.key});

  // Helper function declarations before build method
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
                  () {}, // Add settings navigation logic
                ),
                _drawerItem(
                  context,
                  CupertinoIcons.question,
                  'Help',
                  () {}, // Add help navigation logic
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

  void _showAvailableCars(
    BuildContext context,
    WidgetRef ref,
    String pickup,
    String destination,
    Map<String, double> fares,
    Future<void> Function(String) submitRideRequest,
  ) {
    final cars = [
      {
        'name': 'Economy',
        'seats': '4 seats',
        'icon':
            'lib/shared/assets/economy.png', // Replace with actual asset path
        'eta': '5-10 mins',
      },
      {
        'name': 'Basic',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/basic.png', // Replace with actual asset path
        'eta': '6-12 mins',
      },
      {
        'name': 'Executive',
        'seats': '4 seats',
        'icon':
            'lib/shared/assets/executive.png', // Replace with actual asset path
        'eta': '4-8 mins',
      },
      {
        'name': 'Minivan',
        'seats': '6 seats',
        'icon':
            'lib/shared/assets/minivan.png', // Replace with actual asset path
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
                    await submitRideRequest(name);
                    _showSearchingBottomSheet(
                        context, ref, pickup, destination, name, fares);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showSearchingBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String pickup,
    String destination,
    String carType,
    Map<String, double> fares,
  ) {
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
                  step.value = 'arriving';
                } else {
                  counter.value--;
                }
              });
              return null;
            }, []);

            if (step.value == 'searching') {
              return _buildStatusSheet(
                context,
                "Searching for a driver...",
                const CupertinoActivityIndicator(radius: 22),
                "Estimated wait time: ${counter.value} seconds",
              );
            }

            if (step.value == 'arriving') {
              return _buildRideStatus(
                title: "Driver Arriving",
                subtitle: "Alex Johnson • 3 minutes away",
                buttonText: "Start Ride",
                onPressed: () => step.value = 'on_ride',
              );
            }

            if (step.value == 'on_ride') {
              return _buildRideStatus(
                title: "On Ride",
                subtitle: "Enjoy your trip to $destination",
                buttonText: "Finish Ride",
                onPressed: () => step.value = 'completed',
              );
            }

            if (step.value == 'completed') {
              return _buildPaymentSheet(context, totalFare);
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildStatusSheet(
      BuildContext context, String title, Widget loader, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loader,
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(subtitle),
        ],
      ),
    );
  }

  Widget _buildRideStatus({
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const CircleAvatar(
              backgroundImage: AssetImage(
                  'lib/shared/assets/driver_avatar.png'), // Replace with actual asset path
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
    final userPosition = useState<LatLng?>(null);
    final destinationPosition = useState<LatLng?>(null);
    final polylinePoints = useState<List<LatLng>>([]);
    final estimatedFare = useState<Map<String, double>>({});
    final mapController = useMemoized(() => MapController(), []);

    final fareRates = {
      'Economy': {'base': 120.0, 'perKm': 10.0},
      'Basic': {'base': 140.0, 'perKm': 12.0},
      'Executive': {'base': 180.0, 'perKm': 15.0},
      'Minivan': {'base': 200.0, 'perKm': 18.0},
    };

    useEffect(() {
      Future<void> fetchLocation() async {
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
          userPosition.value = LatLng(position.latitude, position.longitude);

          final placemarks = await placemarkFromCoordinates(
              position.latitude, position.longitude);
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

      fetchLocation();
      return null;
    }, []);

    Future<void> calculateEstimatedFare() async {
      if (userPosition.value == null || destinationPosition.value == null)
        return;

      try {
        double distanceMeters = Geolocator.distanceBetween(
          userPosition.value!.latitude,
          userPosition.value!.longitude,
          destinationPosition.value!.latitude,
          destinationPosition.value!.longitude,
        );

        double distanceKm = distanceMeters / 1000.0;

        final fares = <String, double>{};
        fareRates.forEach((type, rate) {
          double total = rate['base']! + (rate['perKm']! * distanceKm);
          fares[type] = total;
        });

        estimatedFare.value = fares;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculating fare: $e')),
        );
      }
    }

    Future<void> submitRideRequest(String carType) async {
      if (userPosition.value == null || destinationController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select pickup and destination')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final riderId = prefs.getString('userObjectId') ??
          'rider_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('userObjectId', riderId);

      final request = RideRequest(
        riderId: riderId,
        pickup: pickupController.text,
        destination: destinationController.text,
        carType: carType,
        pickupLatitude: userPosition.value!.latitude,
        pickupLongitude: userPosition.value!.longitude,
        createdAt: DateTime.now().toUtc(),
      );

      try {
        // Step 1: Log the JSON payload for debugging
        final requestJson = {
          ...request.toJson(),
          'status': 'pending',
          'assignedDriverId': null,
          'riderId': {
            '__type': 'Pointer',
            'className': '_User',
            'objectId': riderId,
          },
        };
        print('RideRequest JSON Payload: $requestJson');

        // Step 2: Create the ride request
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

        // Step 3: Parse and validate objectId
        final createdObject = jsonDecode(createResponse.body);
        print('Create Response: $createdObject');
        final objectId = createdObject['objectId'];

        if (objectId == null || objectId is! String || objectId.isEmpty) {
          throw Exception(
              'Invalid or missing objectId in create response: $createdObject');
        }

        // Step 4: Assign the ride request to a driver
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

        // Step 5: Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride request submitted successfully')),
        );
      } catch (e) {
        // Step 6: Show error message with context
        print('Error submitting ride request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error submitting ride request: ${e.toString()}')),
        );
        rethrow; // For further debugging
      }
    }

    return Scaffold(
      drawer: _buildSideNavBar(context),
      body: Stack(
        children: [
          // Map display with loading state
          if (userPosition.value == null)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                center: userPosition.value!,
                zoom: 15.0,
                onTap: (tapPosition, point) async {
                  destinationPosition.value = point;

                  try {
                    final placemarks = await placemarkFromCoordinates(
                      point.latitude,
                      point.longitude,
                    );
                    final place = placemarks.first;
                    destinationController.text =
                        '${place.street}, ${place.locality}, ${place.country}';
                  } catch (e) {
                    destinationController.text = 'Unknown location';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error geocoding location: $e')),
                    );
                  }

                  if (userPosition.value != null) {
                    polylinePoints.value = [userPosition.value!, point];
                    await calculateEstimatedFare();
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
                      point: userPosition.value!,
                      builder: (ctx) => const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                    if (destinationPosition.value != null)
                      Marker(
                        width: 50.0,
                        height: 50.0,
                        point: destinationPosition.value!,
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
                    if (polylinePoints.value.isNotEmpty)
                      Polyline(
                        points: polylinePoints.value,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                  ],
                ),
              ],
            ),
          // Top navigation bar
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
          // Bottom search card
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
                              destinationPosition.value = dest;
                              polylinePoints.value = [
                                userPosition.value!,
                                dest
                              ];
                              await calculateEstimatedFare();
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
                            context,
                            ref,
                            pickupController.text,
                            destinationController.text,
                            estimatedFare.value,
                            submitRideRequest,
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
