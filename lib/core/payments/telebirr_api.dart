import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class TelebirrPaymentService {
  final String baseUrl =
      'https://api.telebirr.et/v1'; // Replace with actual telebirr API base URL
  final String appKey;
  final String appSecret;
  final String shortCode;
  final Map<String, String> headers;

  TelebirrPaymentService({
    required this.appKey,
    required this.appSecret,
    required this.shortCode,
  }) : headers = {
          'Content-Type': 'application/json',
          'App-Key': appKey,
          // Add other headers as required by telebirr (e.g., Authorization token)
        };

  /// Initializes a payment request with telebirr API.
  /// [amount]: Payment amount (e.g., 100.00).
  /// [msisdn]: Customer's mobile number (e.g., '0912345678').
  /// [transactionId]: Unique transaction ID (auto-generated if null).
  /// [description]: Payment description (optional).
  /// [callbackUrl]: URL to receive payment status (optional).
  /// Returns a map with payment details or error message.
  Future<Map<String, dynamic>> initiatePayment({
    required double amount,
    required String msisdn,
    String? transactionId,
    String? description,
    String? callbackUrl,
  }) async {
    try {
      final String txId = transactionId ?? const Uuid().v4();
      final Map<String, dynamic> payload = {
        'appKey': appKey,
        'shortCode': shortCode,
        'amount': amount.toString(),
        'msisdn': msisdn, // Customer's mobile number
        'transactionId': txId,
        'description': description ?? 'Payment for services',
        'callbackUrl': callbackUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // telebirr may require signing the payload (e.g., with appSecret)
      // Add signature logic here if required by the API
      // Example: payload['signature'] = generateSignature(payload, appSecret);

      final response = await http.post(
        Uri.parse('$baseUrl/payment/initiate'), // Replace with actual endpoint
        headers: headers,
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        return {
          'success': true,
          'transactionId': txId,
          'paymentUrl': responseData['data']['paymentUrl'] ??
              '', // URL for user confirmation (if applicable)
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to initiate payment',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error initiating payment: $e',
      };
    }
  }

  /// Verifies a transaction using the transaction ID.
  /// [transactionId]: Unique transaction ID.
  /// Returns a map with transaction status or error details.
  Future<Map<String, dynamic>> verifyTransaction(String transactionId) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/payment/verify/$transactionId'), // Replace with actual endpoint
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
