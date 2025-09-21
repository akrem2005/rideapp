// ... other imports
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../providers/auth_provider.dart';
import 'otp_verify_page.dart';

class PhoneInputPage extends HookConsumerWidget {
  const PhoneInputPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneNumber = useState<String>('');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const BackButton(),
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'lib/shared/assets/phone2.png',
                  height: 180,
                  width: 180,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 48),
              const Center(
                child: Text(
                  'Enter Your Phone Number',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF34A853), // Orange
                  ),
                ),
              ),
              const SizedBox(height: 32),
              IntlPhoneField(
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  filled: true,
                  fillColor: const Color.fromARGB(255, 241, 237, 237),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                initialCountryCode: 'ET',
                onChanged: (phone) {
                  phoneNumber.value = phone.completeNumber;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).sendOtp(phoneNumber.value);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OTPVerifyPage(phoneNumber: phoneNumber.value),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF34A853), // Green
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
