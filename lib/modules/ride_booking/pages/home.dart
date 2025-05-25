import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'discount_page.dart';
import 'order_history_page.dart';

class RideRequestPage extends HookConsumerWidget {
  const RideRequestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupController = useTextEditingController();
    final destinationController = useTextEditingController();

    return Scaffold(
      drawer: _buildSideNavBar(context),
      body: Stack(
        children: [
          // Background map
          Positioned.fill(
            child: Image.asset(
              'lib/shared/assets/maps.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Top bar
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
                    child: PopupMenuButton<String>(
                      icon: const Icon(CupertinoIcons.bell,
                          color: Color(0xFF555555)),
                      onSelected: (value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Selected: $value")),
                        );
                      },
                      itemBuilder: (context) => [],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom card
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
                                  hintText: 'Enter pickup location',
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final cars = ['Toyota Prius', 'Honda Civic', 'Tesla Model 3', 'BMW X5'];
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
                  leading: const Icon(CupertinoIcons.car),
                  title: Text(car),
                  subtitle: const Text("ETA: 5-10 mins"),
                  onTap: () {
                    Navigator.pop(context);
                    _showSearchingBottomSheet(context, car);
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
              // Show searching with countdown
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Searching for driver...",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text("Estimated wait time: ${counter.value} seconds"),
                  ],
                ),
              );
            } else {
              // Show driver info after countdown
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Driver Found!",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundImage:
                            AssetImage('lib/shared/assets/driver_avatar.png'),
                      ),
                      title: Text("Alex Johnson"),
                      subtitle: const Text("Arriving in 3 minutes"),
                      trailing: const Icon(CupertinoIcons.phone),
                      onTap: () {
                        // Optional: Add call driver logic
                      },
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
                        child: const Text(
                          'Confirm',
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
              );
            }
          },
        );
      },
    );
  }

  Drawer _buildSideNavBar(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF5F5F5),
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
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: AssetImage('lib/shared/assets/avatar.png'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "John Doe",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _drawerCard(
                  icon: CupertinoIcons.time,
                  label: "Trip Orders",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const OrderHistoryPage()),
                    );
                  },
                ),
                _drawerCard(
                  icon: CupertinoIcons.tag,
                  label: "Discounts",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DiscountPage()),
                    );
                  },
                ),
                _drawerCard(
                  icon: CupertinoIcons.lock,
                  label: "Privacy Policy",
                  onTap: () {},
                ),
                _drawerCard(
                  icon: CupertinoIcons.doc_text,
                  label: "Terms & Conditions",
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _drawerCard(
                  icon: CupertinoIcons.square_arrow_right,
                  label: "Logout",
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {
                    // Add logout logic
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF555555),
    Color textColor = Colors.black,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label, style: TextStyle(color: textColor, fontSize: 16)),
        onTap: onTap,
      ),
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
