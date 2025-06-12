import 'dart:math';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class DriverService {
  static Future<String?> registerDriver(Map<String, dynamic> data) async {
    try {
      final driver = ParseObject('Driver')
        ..set('name', data['name'])
        ..set('phone', data['phone'])
        ..set('license', data['license'])
        ..set('model', data['model'])
        ..set('year', data['year'])
        ..set('passengers', data['passengers'])
        ..set('color', data['color'])
        ..set('plate', data['plate'])
        ..set('board', data['board'])
        ..set('tin', data['tin'])
        ..set('code', _generateAlphanumericCode());

      final saveResult = await driver.save();
      return saveResult.success
          ? null
          : saveResult.error?.message ?? 'Unknown error saving driver.';
    } catch (e) {
      return 'Exception: ${e.toString()}';
    }
  }

  static String _generateAlphanumericCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    // Generate a 4-character alphanumeric code
    return String.fromCharCodes(
      Iterable.generate(
        4,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}