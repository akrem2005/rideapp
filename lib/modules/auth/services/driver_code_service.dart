import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class DriverAuthService {
  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    try {
      // Normalize inputs
      final normalizedPhone = phone.trim().replaceAll(' ', '');
      final normalizedCode = code.trim();

      // Log inputs for debugging
      print(
          'Querying Driver with phone: $normalizedPhone, code: $normalizedCode');

      final query = QueryBuilder<ParseObject>(ParseObject('Driver'))
        ..whereEqualTo('phone', normalizedPhone)
        ..whereEqualTo('code', normalizedCode);

      final response = await query.query();

      if (response.success) {
        print('Query response: ${response.results}');
        if (response.results != null && response.results!.isNotEmpty) {
          final driver = response.results!.first as ParseObject;
          return {
            'success': true,
            'objectId': driver.get<String>('objectId'),
          };
        } else {
          return {
            'success': false,
            'error': 'No matching driver found for the provided phone and code',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Query failed: ${response.error?.message}',
        };
      }
    } catch (e) {
      print('Verification error: $e');
      return {
        'success': false,
        'error': 'Verification failed: ${e.toString()}',
      };
    }
  }
}
