import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'driver_verify.dart';
import '../providers/driver_provider.dart';

class DriverRegistrationPage extends StatefulWidget {
  const DriverRegistrationPage({super.key});

  @override
  State<DriverRegistrationPage> createState() => _DriverRegistrationPageState();
}

class _DriverRegistrationPageState extends State<DriverRegistrationPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final ImagePicker _imagePicker = ImagePicker();

  void _nextPage(DriverProvider provider) {
    if (_currentPage == 0 && !_validateDriverInfo(provider)) {
      _showError('Please fill in all driver information.');
      return;
    } else if (_currentPage == 1 && !_validateVehicleInfo(provider)) {
      _showError('Please fill in all vehicle details and upload a photo.');
      return;
    }
    if (_currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  bool _validateDriverInfo(DriverProvider provider) {
    return provider.name.text.isNotEmpty &&
        provider.phone.text.isNotEmpty &&
        provider.license.text.isNotEmpty;
  }

  bool _validateVehicleInfo(DriverProvider provider) {
    return provider.model.text.isNotEmpty &&
        provider.year.text.isNotEmpty &&
        provider.passengers.text.isNotEmpty &&
        provider.color.text.isNotEmpty &&
        provider.plate.text.isNotEmpty &&
        provider.board.text.isNotEmpty;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color.fromARGB(255, 241, 237, 237),
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> pickVehiclePhoto(DriverProvider provider) async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      provider.vehiclePhoto = File(pickedFile.path);
      setState(() {});
    }
  }

  Future<void> pickBusinessLicense(DriverProvider provider) async {
    // final result = await FilePicker.platform.pickFiles(type: FileType.any);
    // if (result != null && result.files.isNotEmpty) {
    //   provider.businessLicense = File(result.files.first.path!);
    //   provider.businessLicenseController.text = result.files.first.name;
    //   setState(() {});
    // }
  }

  Future<void> pickInsuranceCertificate(DriverProvider provider) async {
    // final result = await FilePicker.platform.pickFiles(type: FileType.any);
    // if (result != null && result.files.isNotEmpty) {
    //   provider.insuranceCertificate = File(result.files.first.path!);
    //   provider.insuranceCertificateController.text = result.files.first.name;
    //   setState(() {});
    // }
  }

  Widget _buildDriverConsoleButton() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DriverVerifyPage(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              const Color.fromARGB(255, 255, 255, 255), // Orange background
          foregroundColor: const Color(0xFFFFA726), // White text/icon color
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
        child: const Text('Driver Login'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final provider = ref.watch(driverProvider);

          return PageView(
            controller: _controller,
            onPageChanged: (index) => setState(() => _currentPage = index),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Page 1: Driver Info
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Image.asset(
                        'lib/shared/assets/reg.png', // Replace with your image path
                        width: 150,
                        height: 150,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Driver Registration",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFA726),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: provider.name,
                      decoration: _inputDecoration(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: provider.phone,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        label: 'Phone Number',
                        icon: Icons.phone,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: provider.license,
                      decoration: _inputDecoration(
                        label: 'Driver License Number',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _nextPage(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA726),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Next",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDriverConsoleButton(),
                  ],
                ),
              ),

              // Page 2: Vehicle Details
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text(
                          "Vehicle Details",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFA726),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => pickVehiclePhoto(provider),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: provider.vehiclePhoto != null
                                ? FileImage(provider.vehiclePhoto!)
                                : null,
                            child: provider.vehiclePhoto == null
                                ? const Icon(Icons.directions_car,
                                    color: Colors.black)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            provider.vehiclePhoto == null
                                ? "Add a photo"
                                : "Change photo",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: provider.model,
                      decoration: _inputDecoration(
                        label: 'Model',
                        hint: 'e.g. Toyota Vitz',
                        icon: Icons.directions_car,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: provider.year,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              label: 'Production Year',
                              icon: Icons.date_range,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: provider.passengers,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(
                              label: 'Number of Passengers',
                              icon: Icons.group,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: provider.color,
                      decoration: _inputDecoration(
                        label: 'Color',
                        icon: Icons.color_lens,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: provider.plate,
                      decoration: _inputDecoration(
                        label: 'Plate Number',
                        icon: Icons.confirmation_number,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: provider.board,
                      decoration: _inputDecoration(
                        label: 'Board Number',
                        icon: Icons.format_list_numbered,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _nextPage(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA726),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Next",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDriverConsoleButton(),
                  ],
                ),
              ),

              // Page 3: Documents
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        const Text(
                          "Document Registration",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFA726),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: provider.tin,
                      decoration: _inputDecoration(
                        label: 'TIN No',
                        icon: Icons.numbers,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: provider.businessLicenseController,
                      readOnly: true,
                      onTap: () => pickBusinessLicense(provider),
                      decoration: _inputDecoration(
                        label: 'Business License Upload',
                        icon: Icons.business,
                        hint: provider.businessLicenseController.text.isNotEmpty
                            ? provider.businessLicenseController.text
                            : 'Tap to upload file',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: provider.insuranceCertificateController,
                      readOnly: true,
                      onTap: () => pickInsuranceCertificate(provider),
                      decoration: _inputDecoration(
                        label: 'Insurance Certificate Upload',
                        icon: Icons.insert_drive_file,
                        hint: provider
                                .insuranceCertificateController.text.isNotEmpty
                            ? provider.insuranceCertificateController.text
                            : 'Tap to upload file',
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // if (provider.tin.text.isEmpty ||
                          //     provider.businessLicense == null ||
                          //     provider.insuranceCertificate == null) {
                          //   _showError('Please provide all documents.');
                          //   return;
                          // }
                          final error = await provider.submit();
                          if (error == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Driver registered successfully!'),
                              ),
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DriverVerifyPage(),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $error')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA726),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Submit",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDriverConsoleButton(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
