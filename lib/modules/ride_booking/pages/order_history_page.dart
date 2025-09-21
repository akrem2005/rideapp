import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RideHistoryEntry {
  final String? id;
  final String? carType;
  final String? plateNumber;
  final String? pickup;
  final String? destination;
  final String? requestTime;
  final String? status;
  final String? fare;

  RideHistoryEntry({
    this.id,
    this.carType,
    this.plateNumber,
    this.pickup,
    this.destination,
    this.requestTime,
    this.status,
    this.fare,
  });

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RideHistoryEntry(
      id: json['id'] as String?,
      carType: json['carType'] as String? ?? 'Taxi Economy',
      plateNumber: json['plate'] as String?,
      pickup: json['pickup'] as String?,
      destination: json['destination'] as String?,
      requestTime: json['timestamp'] as String?,
      status: json['status'] as String?,
      fare: json['fare']?.toString(),
    );
  }
}

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<RideHistoryEntry> _rides = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    List<RideHistoryEntry> rides = [];

    for (String key in allKeys) {
      if (key.startsWith('ride_history_')) {
        final historyJson = prefs.getString(key) ?? '[]';
        final List<dynamic> historyList = jsonDecode(historyJson);
        rides.addAll(historyList
            .map((item) => RideHistoryEntry.fromJson(item))
            .toList());
      }
    }

    rides.sort((a, b) {
      final aTime =
          a.requestTime != null ? DateTime.tryParse(a.requestTime!) : null;
      final bTime =
          b.requestTime != null ? DateTime.tryParse(b.requestTime!) : null;
      return (bTime ?? DateTime(0)).compareTo(aTime ?? DateTime(0));
    });

    setState(() {
      _rides = rides;
      _isLoading = false;
    });
  }

  String _getCarIcon(String? carType) {
    final type = (carType ?? '').toLowerCase();
    if (type.contains('economy')) return 'lib/shared/assets/economy.png';
    if (type.contains('basic')) return 'lib/shared/assets/basic.png';
    if (type.contains('executive')) return 'lib/shared/assets/executive.png';
    if (type.contains('minivan')) return 'lib/shared/assets/minivan.png';
    return 'lib/shared/assets/economy.png'; // fallback
  }

  @override
  Widget build(BuildContext context) {
    const mainTextColor = Color(0xFF2d2c2a);
    const subTextColor = Color(0xFF858482);

    Map<String, List<RideHistoryEntry>> grouped = {};
    for (var ride in _rides) {
      final date = ride.requestTime != null
          ? DateFormat('EEEE, MMM d')
              .format(DateTime.tryParse(ride.requestTime!) ?? DateTime.now())
          : 'Unknown Date';
      grouped.putIfAbsent(date, () => []).add(ride);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(height: 100),
                const Text(
                  "My Rides and Orders",
                  style: TextStyle(
                    color: Color(0xFF393939),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: mainTextColor))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: subTextColor,
                          ),
                        ),
                      ),
                      ...entry.value.map((ride) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F4F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.asset(
                                    _getCarIcon(ride.carType),
                                    width: 40,
                                    height: 40,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${ride.carType ?? 'Taxi'}${ride.requestTime != null ? ', ${DateFormat.Hm().format(DateTime.tryParse(ride.requestTime!) ?? DateTime.now())}' : ''}',
                                        style: const TextStyle(
                                          color: mainTextColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      // ...existing code...
                                      Text(
                                        ride.destination != null
                                            ? (ride.destination!.length > 28
                                                ? '${ride.destination!.substring(0, 28)}...'
                                                : ride.destination!)
                                            : 'Unknown Destination',
                                        style: const TextStyle(
                                          color: subTextColor,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
// ...existing code...
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                '${ride.fare ?? '--'} ETB',
                                style: const TextStyle(
                                  color: mainTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
      ),
    );
  }
}
