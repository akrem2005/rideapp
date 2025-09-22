import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './../../auth/pages/get_started_page.dart';

class RiderSettingsPage extends StatefulWidget {
  const RiderSettingsPage({super.key});

  @override
  State<RiderSettingsPage> createState() => _RiderSettingsPageState();
}

class _RiderSettingsPageState extends State<RiderSettingsPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String _phoneNumber = "+251929175653";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstNameController.text = prefs.getString('userFirstName') ?? '';
      _lastNameController.text = prefs.getString('userLastName') ?? '';
      _phoneNumber = prefs.getString('userPhoneNumber') ?? "+251929175653";
    });
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final objectId = prefs.getString('userObjectId') ??
          'No user ID found'; // Provide a fallback in case null

      if (objectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user found')),
          );
        }
        return;
      }

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phoneNumber = _phoneNumber;

      if (firstName.isEmpty || lastName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill all fields')),
          );
        }
        return;
      }

      final ParseObject userObject = ParseObject('OtpVerification')
        ..objectId = objectId;
      userObject
        ..set('Name', "$firstName + $lastName")
        ..set('updatedAt', DateTime.now());

      final response = await userObject.save();

      if (response.success && response.result != null) {
        await prefs.setString('userName', "$firstName $lastName");
        await prefs.setString('userPhoneNumber', phoneNumber);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Color(0xFF34A853),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to update profile: ${response.error?.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_isLoading) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final objectId = prefs.getString('userObjectId');
      if (objectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user found')),
          );
        }
        return;
      }

      final userObject = ParseObject('OtpVerification')..objectId = objectId;
      final deleteResponse = await userObject.delete();

      if (deleteResponse.success) {
        await prefs.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
          if (context.mounted) {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const GetStartedPage()));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to delete account: ${deleteResponse.error?.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF34A853)),
                    ),
                  )
                : const Text(
                    "Save",
                    style: TextStyle(
                      color: Color(0xFF34A853),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        TextField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            hintText: 'First name',
                            hintStyle: const TextStyle(
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
                        ),

                        const SizedBox(height: 16),

                        // Last name
                        TextField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            hintText: 'Last name',
                            hintStyle: const TextStyle(
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
                        ),

                        const SizedBox(height: 16),

                        // Phone field
                        IntlPhoneField(
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
                          initialValue: _phoneNumber.substring(4),
                          onChanged: (phone) {
                            setState(() {
                              _phoneNumber = phone.completeNumber;
                            });
                          },
                        ),

                        const SizedBox(height: 30),

                        // Delete account button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _deleteAccount,
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
