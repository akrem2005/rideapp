import 'dart:math';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  /// Sends OTP to a phone number and saves it to Parse Server.
  Future<bool> sendOtp(String phoneNumber) async {
    final otp = _generateOtp();
    final prefs = await SharedPreferences.getInstance();

    // Delete any existing OTPs for this number
    final query = QueryBuilder<ParseObject>(ParseObject('OtpVerification'))
      ..whereEqualTo('phoneNumber', phoneNumber);
    final existing = await query.query();
    if (existing.success && existing.results != null) {
      for (var record in existing.results!) {
        await (record as ParseObject).delete();
      }
    }

    final otpEntry = ParseObject('OtpVerification')
      ..set('phoneNumber', phoneNumber)
      ..set('otp', otp)
      ..set('isVerified', false)
      ..set('expiresAt', DateTime.now().add(const Duration(minutes: 5)));

    final response = await otpEntry.save();

    if (response.success && response.result != null) {
      // Save objectId to SharedPreferences
      final objectId = (response.result as ParseObject).objectId;
      if (objectId != null) {
        await prefs.setString('userObjectId', objectId);
      }
      // Send OTP via SMS API (simulate for now)
      print('OTP sent to $phoneNumber is $otp'); // Replace with real SMS API
      return true;
    }

    return false;
  }

  /// Verifies OTP entered by the user
  Future<bool> verifyOtp(String phoneNumber, String otpCode) async {
    final prefs = await SharedPreferences.getInstance();
    final query = QueryBuilder<ParseObject>(ParseObject('OtpVerification'))
      ..whereEqualTo('phoneNumber', phoneNumber)
      ..whereEqualTo('otp', otpCode);

    final result = await query.query();

    if (result.success &&
        result.results != null &&
        result.results!.isNotEmpty) {
      final entry = result.results!.first as ParseObject;
      final expiry = entry.get<DateTime>('expiresAt');

      if (expiry != null && DateTime.now().isBefore(expiry)) {
        entry.set('isVerified', true);
        await entry.save();
        // Save objectId to SharedPreferences
        final objectId = entry.objectId;
        if (objectId != null) {
          await prefs.setString('userObjectId', objectId);
        }
        return true;
      }
    }

    return false;
  }

  String _generateOtp() {
    final rand = Random();
    return (1000 + rand.nextInt(9000)).toString(); // 4-digit OTP
  }
}
