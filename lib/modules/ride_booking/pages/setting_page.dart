import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class RiderSettingsPage extends StatelessWidget {
  const RiderSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<String> phoneNumber = ValueNotifier("+251929175653");

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF21201E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Color(0xFF21201E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // handle save
              debugPrint("Saved phone: ${phoneNumber.value}");
            },
            child: const Text(
              "Save",
              style: TextStyle(
                color: Color(0xFF34A853), // green accent
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Profile picture with edit button
                  Stack(
                    children: [
                      const CircleAvatar(
                        radius: 48,
                        backgroundColor: Color(0xFFF5F4F2),
                        child: Icon(Icons.person,
                            size: 48, color: Color(0xFF9E9E9E)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF34A853),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // First name
                  _buildTextField("First name"),

                  const SizedBox(height: 16),

                  // Last name
                  _buildTextField("Last name"),


                  const SizedBox(height: 16),

                  // Phone field (locked)
                  AbsorbPointer(
                    absorbing: true, // disables input
                    child: IntlPhoneField(
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(
                          color: Color(0xFF21201E),
                          fontSize: 16,
                        ),
                        filled: true,
                        fillColor: Color(0xFFF5F4F2),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      initialCountryCode: 'ET',
                      initialValue: '929175653',
                      onChanged: (phone) {
                        phoneNumber.value = phone.completeNumber;
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Delete account button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // handle delete
                        debugPrint("Delete my account pressed");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Delete my account",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer text
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              "© All rights reserved",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF21201E),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Color(0xFFF5F4F2),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
