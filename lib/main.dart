import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Import Riverpod
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart'; // ✅ Import Parse SDK
import './modules/auth/pages/get_started_page.dart';
import 'core/config/app_config.dart';
import "modules/ride_booking/pages/riderequest_page.dart";
// ✅ Ensure path is correct

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(primarySwatch: Colors.orange),
        // home: const GetStartedPage(),
        home: const RideRequestPage());
  }
}
