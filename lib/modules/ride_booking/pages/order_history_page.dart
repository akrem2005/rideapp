import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RideHistoryEntry {
  final String? id; // Ride ID
  final String? riderId;
  final String? rideDetails; // Combine pickup, destination, carType
  final String? requestTime; // Maps to timestamp
  final String? status;

  RideHistoryEntry({
    this.id,
    this.riderId,
    this.rideDetails,
    this.requestTime,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'riderId': riderId,
        'rideDetails': rideDetails,
        'requestTime': requestTime,
        'status': status,
      };

  factory RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    // Construct ride details from pickup, destination, and carType
    final pickup = json['pickup'] as String? ?? 'Unknown pickup';
    final destination = json['destination'] as String? ?? 'Unknown destination';
    final carType = json['carType'] as String? ?? 'Unknown car type';
    final rideDetails = 'From: $pickup\nTo: $destination\nType: $carType';

    return RideHistoryEntry(
      id: json['id'] as String? ?? 'Unknown',
      riderId: json['riderId'] as String? ?? 'Unknown',
      rideDetails: rideDetails,
      requestTime: json['timestamp'] as String? ?? 'No time',
      status: json['status'] as String? ?? 'Unknown',
    );
  }
}

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<RideHistoryEntry> _allRideRequests = [];
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchRideRequests();
  }

  Future<void> _fetchRideRequests() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      List<RideHistoryEntry> allRides = [];

      for (String key in allKeys) {
        if (key.startsWith('ride_history_')) {
          final historyJson = prefs.getString(key) ?? '[]';
          try {
            final List<dynamic> historyList = jsonDecode(historyJson);
            allRides.addAll(
              historyList.map((item) =>
                  RideHistoryEntry.fromJson(item as Map<String, dynamic>)),
            );
          } catch (e) {
            print('Error parsing history for key $key: $e');
          }
        }
      }

      // Sort rides by requestTime (timestamp) in descending order
      allRides.sort((a, b) {
        final aTime = a.requestTime != null
            ? DateTime.tryParse(a.requestTime!) ?? DateTime(0)
            : DateTime(0);
        final bTime = b.requestTime != null
            ? DateTime.tryParse(b.requestTime!) ?? DateTime(0)
            : DateTime(0);
        return bTime.compareTo(aTime); // Latest first
      });

      if (!mounted) return;

      setState(() {
        _allRideRequests = allRides;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      _showSnackBar('An error occurred: $e', isError: true);
    }
  }

  Future<void> _clearAllRideHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    for (String key in allKeys) {
      if (key.startsWith('ride_history_')) {
        await prefs.remove(key);
      }
    }

    setState(() {
      _allRideRequests = [];
    });

    _showSnackBar('All ride history cleared');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: const Color(0xFFFFA500),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFA500),
          primary: const Color(0xFFFFA500),
          secondary: Colors.blue[100],
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'All Ride Requests',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _fetchRideRequests,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Clear All History',
              onPressed: _allRideRequests.isEmpty
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear All Ride History?'),
                          content: const Text(
                            'This will permanently delete all ride history. Are you sure?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                _clearAllRideHistory();
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
            ),
          ],
          elevation: 0,
          backgroundColor: const Color(0xFFFFA500),
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading ride history...'),
                  ],
                ),
              )
            : _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[700],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load ride history',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchRideRequests,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _allRideRequests.isEmpty
                    ? const Center(
                        child: Text(
                          'No ride requests found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchRideRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _allRideRequests.length,
                          itemBuilder: (context, index) {
                            final request = _allRideRequests[index];
                            return AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Text(
                                    'Ride ID: ${request.id ?? 'Unknown'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request.rideDetails ?? 'No details',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Time: ${request.requestTime ?? 'No time'}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          'Status: ${request.status ?? 'Unknown'}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.info_outline),
                                    color: const Color(0xFFFFA500),
                                    tooltip: 'View Details',
                                    onPressed: () {
                                      // Placeholder for detailed view navigation
                                      _showSnackBar(
                                          'Details for Ride ID: ${request.id}');
                                    },
                                  ),
                                  onTap: () {
                                    // Tap card to view details
                                    _showSnackBar(
                                        'Details for Ride ID: ${request.id}');
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
