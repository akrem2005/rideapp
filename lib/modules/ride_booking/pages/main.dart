import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'discount_page.dart';
import 'order_history_page.dart';

class RideRequestPage extends HookConsumerWidget {
  const RideRequestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupController =
        useTextEditingController(text: 'Fetching location...');
    final destinationController = useTextEditingController();

    // Use effect to fetch location once
    useEffect(() {
      Future<void> setLocation() async {
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

          final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          final placemarks = await placemarkFromCoordinates(
              position.latitude, position.longitude);
          final place = placemarks.first;

          pickupController.text =
              '${place.street}, ${place.locality}, ${place.country}';
        } catch (e) {
          pickupController.text = 'Location unavailable';
        }
      }

      setLocation();
      return null;
    }, []);

    return Scaffold(
      drawer: _buildSideNavBar(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/shared/assets/maps.jpg',
              fit: BoxFit.cover,
            ),
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
                      child: Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(CupertinoIcons.bars,
                              size: 28, color: Color(0xFF555555)),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.bell,
                        color: Color(0xFF555555)),
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _iconBox(CupertinoIcons.location),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pickup',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: pickupController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Destination',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: destinationController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter destination',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showAvailableCars(context),
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

  void _showAvailableCars(BuildContext context) {
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
              ...cars.map(
                (car) => ListTile(
                  leading: Image.asset(
                    car['icon'] as String,
                    width: 65,
                    height: 65,
                  ),
                  title: Text(car['name'] as String),
                  subtitle: Text('${car['seats']} • ETA: ${car['eta']}'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSearchingBottomSheet(context, car['name'] as String);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSearchingBottomSheet(BuildContext context, String carName) {
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
                child: SizedBox(
                  width: double.infinity, // Ensures full width
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment
                        .center, // Optional: centers content horizontally
                    children: [
                      const CupertinoActivityIndicator(radius: 22),
                      const SizedBox(height: 20),
                      const Text(
                        "Searching for a driver...",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Estimated wait time: ${counter.value} seconds",
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
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
                        backgroundImage:
                            AssetImage('lib/shared/assets/driver_avatar.png'),
                      ),
                      title: const Text("Alex Johnson"),
                      subtitle: const Text("Arriving in 3 minutes"),
                      trailing: const Icon(CupertinoIcons.phone),
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    "$carName has been successfully booked!")),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA500),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Confirm',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
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

  Drawer _buildSideNavBar(BuildContext context) {
    return Drawer(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFFA500)),
            child: Row(
              children: [
                const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('lib/shared/assets/user.png')),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text("John Doe",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _simpleDrawerItem(
                  icon: CupertinoIcons.time,
                  label: "Trip Orders",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderHistoryPage(),
                      ),
                    );
                  },
                ),
                _simpleDrawerItem(
                  icon: CupertinoIcons.tag,
                  label: "Discounts",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DiscountPage(),
                      ),
                    );
                  },
                ),
                _simpleDrawerItem(
                  icon: CupertinoIcons.lock,
                  label: "Privacy Policy",
                  onTap: () {},
                ),
                _simpleDrawerItem(
                  icon: CupertinoIcons.doc_text,
                  label: "Terms & Conditions",
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _simpleDrawerItem(
                  icon: CupertinoIcons.square_arrow_right,
                  label: "Logout",
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {},
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _simpleDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color.fromARGB(255, 42, 42, 43),
    Color textColor = const Color.fromARGB(255, 42, 42, 43),
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: iconColor),
          title: Text(label, style: TextStyle(color: textColor)),
          onTap: onTap,
        ),
        const Divider(), // Adds underline
      ],
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
      child: Center(
        child: Icon(icon, color: const Color(0xFF555555), size: 28),
      ),
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
}
