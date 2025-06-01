import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../providers/auth_provider.dart';
import '../../ride_booking/pages/main.dart';

class OTPVerifyPage extends HookConsumerWidget {
  final String phoneNumber;

  const OTPVerifyPage({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otpCode = useState<String>('');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const BackButton(),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Verify Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFA500), // Orange
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'lib/shared/assets/pass.png',
                  height: 220,
                  width: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Enter the verification code sent to your number',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (value) => otpCode.value = value,
                keyboardType: TextInputType.number,
                textStyle: const TextStyle(fontSize: 20),
                enableActiveFill: true,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 70,
                  fieldWidth: 65,
                  activeFillColor: const Color.fromARGB(255, 241, 237, 237),
                  inactiveFillColor: const Color.fromARGB(255, 241, 237, 237),
                  selectedFillColor: const Color.fromARGB(255, 241, 237, 237),
                  activeColor: Colors.transparent,
                  inactiveColor: Colors.transparent,
                  selectedColor: Colors.transparent,
                ),
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Didn't receive the code? Resend",
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (otpCode.value.length < 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a 4-digit OTP'),
                        ),
                      );
                      return;
                    }

                    if (phoneNumber == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number missing'),
                        ),
                      );
                      return;
                    }

                    final verified = await ref
                        .read(authProvider.notifier)
                        .verifyOtp(phoneNumber, otpCode.value);

                    if (verified) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('OTP Verified')),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RideRequestPage()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid or expired OTP')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500), // Orange
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Verify',
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
