import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../providers/ride_request_provider.dart';
import 'discount_page.dart';
import 'order_history_page.dart';

class RideRequestPage extends HookConsumerWidget {
  const RideRequestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupController =
        useTextEditingController(text: 'Fetching location...');
    final destinationController = useTextEditingController();
    final userPosition = useState<LatLng?>(null);
    final destinationPosition = useState<LatLng?>(null);
    final polylinePoints = useState<List<LatLng>>([]);

    useEffect(() {
      Future<void> fetchLocation() async {
        try {
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            pickupController.text = 'Location service disabled';
            return;
          }

          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              pickupController.text = 'Permission denied';
              return;
            }
          }

          if (permission == LocationPermission.deniedForever) {
            pickupController.text = 'Permission permanently denied';
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
        }
      }

      fetchLocation();
      return null;
    }, []);

    return Scaffold(
      drawer: _buildSideNavBar(context),
      body: Stack(
        children: [
          userPosition.value == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  options: MapOptions(
                    center: userPosition.value,
                    zoom: 15.0,
                    onTap: (tapPosition, point) async {
                      // Set tapped point as destination
                      destinationPosition.value = point;

                      try {
                        final placemarks = await placemarkFromCoordinates(
                            point.latitude, point.longitude);
                        final place = placemarks.first;
                        destinationController.text =
                            '${place.street}, ${place.locality}, ${place.country}';
                      } catch (e) {
                        destinationController.text = 'Unknown location';
                      }

                      // Update polyline from user to destination
                      if (userPosition.value != null) {
                        polylinePoints.value = [userPosition.value!, point];
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 50.0,
                          height: 50.0,
                          point: userPosition.value!,
                          builder: (ctx) => const Icon(Icons.location_pin,
                              color: Colors.red, size: 40),
                        ),
                        if (destinationPosition.value != null)
                          Marker(
                            width: 50.0,
                            height: 50.0,
                            point: destinationPosition.value!,
                            builder: (ctx) => const Icon(Icons.flag,
                                color: Colors.blue, size: 40),
                          ),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        if (polylinePoints.value.isNotEmpty)
                          Polyline(
                            points: polylinePoints.value,
                            strokeWidth: 4.0,
                            color: Colors.orange,
                          ),
                      ],
                    ),
                  ],
                ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: _iconContainer(CupertinoIcons.bars),
                    ),
                  ),
                  const Spacer(),
                  _iconContainer(CupertinoIcons.bell),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _locationInputRow(pickupController, destinationController),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            List<Location> locations =
                                await locationFromAddress(
                                    destinationController.text);
                            if (locations.isNotEmpty) {
                              final dest = LatLng(locations.first.latitude,
                                  locations.first.longitude);
                              destinationPosition.value = dest;
                              polylinePoints.value = [
                                userPosition.value!,
                                dest
                              ];
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Invalid destination: $e')),
                            );
                          }

                          _showAvailableCars(
                            context,
                            ref,
                            pickupController.text,
                            destinationController.text,
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
                              color: Colors.white),
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
      BuildContext context, WidgetRef ref, String pickup, String destination) {
    final cars = [
      {
        'name': 'Economy',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/economy.png',
        'eta': '5-10 mins'
      },
      {
        'name': 'Basic',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/basic.png',
        'eta': '6-12 mins'
      },
      {
        'name': 'Executive',
        'seats': '4 seats',
        'icon': 'lib/shared/assets/executive.png',
        'eta': '4-8 mins'
      },
      {
        'name': 'Minivan',
        'seats': '6 seats',
        'icon': 'lib/shared/assets/minivan.png',
        'eta': '10-15 mins'
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
              const Text("Available Cars",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...cars.map((car) => ListTile(
                    leading: Image.asset(car['icon']!, width: 60),
                    title: Text(car['name']!),
                    subtitle: Text('${car['seats']} • ETA: ${car['eta']}'),
                    onTap: () {
                      Navigator.pop(context);
                      _showSearchingBottomSheet(
                          context, ref, pickup, destination, car['name']!);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showSearchingBottomSheet(BuildContext context, WidgetRef ref,
      String pickup, String destination, String carName) {
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
            final counter = useState(5);
            final showDriver = useState(false);

            useEffect(() {
              Timer.periodic(const Duration(seconds: 1), (timer) {
                if (counter.value == 0) {
                  timer.cancel();
                  showDriver.value = true;
                } else {
                  counter.value--;
                }
              });
              return null;
            }, []);

            if (!showDriver.value) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 22),
                    const SizedBox(height: 20),
                    const Text("Searching for a driver...",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text("Estimated wait time: ${counter.value} seconds"),
                  ],
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Driver Found!",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const CircleAvatar(
                          backgroundImage: AssetImage(
                              'lib/shared/assets/driver_avatar.png')),
                      title: const Text("Alex Johnson"),
                      subtitle: const Text("Arriving in 3 minutes"),
                      trailing: const Icon(CupertinoIcons.phone),
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final service = ref.read(rideRequestServiceProvider);
                          try {
                            await service.sendRideRequest(
                              pickupLocation: pickup,
                              destination: destination,
                              carType: carName,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('$carName booked successfully!')),
                            );
                          } catch (e) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Booking failed: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA500),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _iconContainer(IconData icon) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
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
        child: Icon(CupertinoIcons.arrow_up_arrow_down,
            color: Colors.grey, size: 28),
      ),
    );
  }

  Drawer _buildSideNavBar(BuildContext context) {
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
                  child: Text("John Doe",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
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
                            builder: (context) => const OrderHistoryPage()))),
                _drawerItem(
                    context,
                    CupertinoIcons.cart,
                    'Promotions',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DiscountPage()))),
                _drawerItem(
                    context, CupertinoIcons.settings, 'Settings', () {}),
                _drawerItem(context, CupertinoIcons.question, 'Help', () {}),
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
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
