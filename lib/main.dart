import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import './modules/auth/pages/get_started_page.dart';
import 'core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "modules/ride_booking/pages/main.dart";
import 'modules/driver_console/pages/driver_console_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Parse().initialize(
    AppConfig.appId,
    AppConfig.serverUrl,
    clientKey: AppConfig.clientKey,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Function to check if driverObjectId exists in SharedPreferences
  Future<bool> _isDriverObjectIdPresent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('driverObjectId') &&
        prefs.getString('driverObjectId') != null;
  }

  // Function to check if userObjectId exists in SharedPreferences
  Future<bool> _isUserObjectIdPresent() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('userObjectId') &&
        prefs.getString('userObjectId') != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride App',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: FutureBuilder<List<bool>>(
        future:
            Future.wait([_isDriverObjectIdPresent(), _isUserObjectIdPresent()]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading screen while checking SharedPreferences
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            final isDriver = snapshot.data![0];
            final isUser = snapshot.data![1];
            if (isDriver) {
              // If driverObjectId exists, navigate to DriverConsolePage
              return const DriverConsolePage();
            } else if (isUser) {
              // If userObjectId exists, navigate to RideRequestPage
              return const RideRequestPage();
            }
          }
          // If neither driverObjectId nor userObjectId exists, navigate to GetStartedPage
          return const GetStartedPage();
        },
      ),
    );
  }
}
