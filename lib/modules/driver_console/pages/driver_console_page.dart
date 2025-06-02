import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../providers/driver_state_provider.dart';
import '../models/ride_request_model.dart';

import '../services/location_service.dart';
import '../providers/location_service_provider.dart';

enum RideStatus { none, accepted, enRoute, pickedUp, completed }

final rideStatusProvider = StateProvider<RideStatus>((ref) => RideStatus.none);

class DriverConsolePage extends HookConsumerWidget {
  const DriverConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isDriverOnlineProvider);
    final rideRequest = ref.watch(incomingRideRequestProvider);
    final rideStatus = ref.watch(rideStatusProvider);
    final mapController = useMemoized(() => MapController());
    final position = useState<LatLng?>(null);
    final pickupPosition = useState<LatLng?>(null);
    final driverId = '001';

    // Get driver location and geocode pickup when ride request updates
    useEffect(() {
      _getCurrentLocation().then((pos) {
        position.value = pos;
        mapController.move(pos, 15.0);
      });

      if (rideRequest != null) {
        _getLatLngFromAddress(rideRequest.pickup).then((pickupLatLng) {
          pickupPosition.value = pickupLatLng;
        });
      }

      return null;
    }, [rideRequest]);

    if (position.value == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
              const Text("Online",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              // Replace with actual user ID from login/session
              // Ideally from ParseUser.currentUser()

              Switch(
                activeColor: Colors.orange,
                value: isOnline,
                onChanged: (value) async {
                  final locationService =
                      ref.read(locationServiceProvider(driverId));

                  if (value) {
                    final currentPos = await _getCurrentLocation();
                    final success =
                        await locationService.sendLocation(currentPos);

                    if (success) {
                      ref.read(isDriverOnlineProvider.notifier).state = true;
                      ref.read(rideStatusProvider.notifier).state =
                          RideStatus.none;
                      _simulateRideRequest(ref);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Failed to send location to server')),
                      );
                    }
                  } else {
                    final success = await locationService.deleteLocation();

                    ref.read(isDriverOnlineProvider.notifier).state = false;
                    ref.read(rideStatusProvider.notifier).state =
                        RideStatus.none;
                    ref.read(incomingRideRequestProvider.notifier).state = null;

                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Failed to delete location')),
                      );
                    }
                  }
                },
              ),

              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: position.value,
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
                  // Driver's location
                  if (position.value != null)
                    Marker(
                      point: position.value!,
                      width: 40,
                      height: 40,
                      builder: (ctx) => const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),

                  // Pickup location
                  if (pickupPosition.value != null)
                    Marker(
                      point: pickupPosition.value!,
                      width: 50,
                      height: 50,
                      builder: (ctx) => const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (rideStatus != RideStatus.none && rideRequest != null)
            _rideBottomSheet(context, ref, rideRequest),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: const [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.orange),
            child: Text("Driver Menu",
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(leading: Icon(Icons.person), title: Text("Profile")),
          ListTile(leading: Icon(Icons.history), title: Text("Ride History")),
          ListTile(leading: Icon(Icons.settings), title: Text("Settings")),
          ListTile(leading: Icon(Icons.logout), title: Text("Logout")),
        ],
      ),
    );
  }

  Widget _rideBottomSheet(
      BuildContext context, WidgetRef ref, RideRequest request) {
    final rideStatus = ref.watch(rideStatusProvider);

    String statusText = switch (rideStatus) {
      RideStatus.accepted => "Navigating to pickup...",
      RideStatus.enRoute => "Rider picked up. Heading to destination...",
      RideStatus.pickedUp => "Almost there...",
      RideStatus.completed => "Ride Completed!",
      _ => "",
    };

    String nextButtonText;
    RideStatus? nextState;

    switch (rideStatus) {
      case RideStatus.accepted:
        nextButtonText = "Start Ride";
        nextState = RideStatus.enRoute;
        break;
      case RideStatus.enRoute:
        nextButtonText = "Picked Up";
        nextState = RideStatus.pickedUp;
        break;
      case RideStatus.pickedUp:
        nextButtonText = "Complete Ride";
        nextState = RideStatus.completed;
        break;
      case RideStatus.completed:
        nextButtonText = "Finish";
        nextState = null;
        break;
      default:
        nextButtonText = "";
        nextState = null;
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text("Ride Info", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _infoRow("Rider", request.riderName),
            _infoRow("Pickup", request.pickup),
            _infoRow("Destination", request.destination),
            _infoRow("Car Type", request.carType),
            const SizedBox(height: 16),
            Text(statusText, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (nextState == null) {
                    ref.read(rideStatusProvider.notifier).state =
                        RideStatus.none;
                    ref.read(incomingRideRequestProvider.notifier).state = null;
                  } else {
                    ref.read(rideStatusProvider.notifier).state = nextState;
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child:
                    Text(nextButtonText, style: const TextStyle(fontSize: 16)),
              ),
            ),
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
          Text("$label: ",
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 16, color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  void _simulateRideRequest(WidgetRef ref) {
    Future.delayed(const Duration(seconds: 2), () {
      ref.read(incomingRideRequestProvider.notifier).state = RideRequest(
        riderName: "Jane Doe",
        pickup: "Addis Ababa, Ethiopia",
        destination: "Bole Airport",
        carType: "Economy",
      );
      ref.read(rideStatusProvider.notifier).state = RideStatus.accepted;
    });
  }

  Future<LatLng> _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }

  Future<LatLng?> _getLatLngFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return null;
  }
}
