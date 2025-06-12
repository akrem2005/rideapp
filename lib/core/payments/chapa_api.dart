import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ChapaPaymentService {
  final String baseUrl = 'https://api.chapa.co/v1';
  final String secretKey;
  final Map<String, String> headers;

  ChapaPaymentService(this.secretKey)
      : headers = {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/json',
        };

  /// Initializes a payment request with Chapa API.
  /// [amount]: Payment amount (e.g., 100.00).
  /// [currency]: Currency code (e.g., 'ETB' for Ethiopian Birr).
  /// [email]: Customer's email.
  /// [firstName]: Customer's first name.
  /// [lastName]: Customer's last name.
  /// [phoneNumber]: Customer's phone number.
  /// [txRef]: Unique transaction reference (auto-generated if null).
  /// [callbackUrl]: URL to receive payment status (optional).
  /// Returns a map with the checkout URL or error details.
  Future<Map<String, dynamic>> initializePayment({
    required double amount,
    required String currency,
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? txRef,
    String? callbackUrl,
  }) async {
    try {
      final String transactionRef = txRef ?? const Uuid().v4();
      final Map<String, dynamic> payload = {
        'amount': amount,
        'currency': currency,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'tx_ref': transactionRef,
        'callback_url': callbackUrl,
        'return_url': callbackUrl, // Optional: URL to redirect after payment
      };

      final response = await http.post(
        Uri.parse('$baseUrl/transaction/initialize'),
        headers: headers,
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        return {
          'success': true,
          'checkout_url': responseData['data']['checkout_url'],
          'tx_ref': transactionRef,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to initialize payment',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error initializing payment: $e',
      };
    }
  }

  /// Verifies a transaction using the transaction reference.
  /// [txRef]: Unique transaction reference.
  /// Returns a map with transaction status or error details.
  Future<Map<String, dynamic>> verifyTransaction(String txRef) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/transaction/verify/$txRef'),
        headers: headers,
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        return {
          'success': true,
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to verify transaction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error verifying transaction: $e',
      };
    }
  }
}
