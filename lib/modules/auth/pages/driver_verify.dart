import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/driver_auth_provider.dart';
import '../../driver_console/pages/driver_console_page.dart'; // Import DriverConsolePage

class DriverVerifyPage extends HookConsumerWidget {
  const DriverVerifyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = useState<String>('');
    final code = useState<String>('');
    final authState = ref.watch(authProvider);

    // Save objectId to SharedPreferences and navigate on successful verification
    useEffect(() {
      if (authState.objectId != null) {
        debugPrint('Verification successful: objectId = ${authState.objectId}');
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('driverObjectId', authState.objectId!);
            debugPrint('Saved driverObjectId to SharedPreferences');

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification Successful'),
                duration: Duration(seconds: 2),
              ),
            );

            // Navigate automatically after snackbar
            Future.delayed(const Duration(seconds: 2), () {
              debugPrint('Navigating to DriverConsolePage');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const DriverConsolePage()),
              );
            });
          } catch (e) {
            debugPrint('Error during verification handling: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        });
      }
      return null;
    }, [authState.objectId]);

    // Show snackbar for errors
    useEffect(() {
      if (authState.error != null) {
        debugPrint('Auth error: ${authState.error}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authState.error!)),
          );
        });
      }
      return null;
    }, [authState.error]);

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
                  'Verify Driver Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFA500),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  phone.value.isEmpty
                      ? 'Enter the verification code sent to your number'
                      : 'Enter the verification code sent to\n${phone.value}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => phone.value = value.trim(),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1234567890',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 241, 237, 237),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              const Text(
                'Security Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (value) => code.value = value.trim(),
                keyboardType: TextInputType.text,
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          if (phone.value.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter a phone number')),
                            );
                            return;
                          }
                          if (code.value.length < 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please enter a 4-digit Security Code')),
                            );
                            return;
                          }
                          final normalizedPhone =
                              phone.value.replaceAll(' ', '');
                          debugPrint(
                              'Verifying OTP for phone: $normalizedPhone, code: ${code.value}');
                          await ref
                              .read(authProvider.notifier)
                              .verifyOtp(normalizedPhone, code.value);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA500),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: authState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
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
