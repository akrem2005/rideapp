import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/driver_service.dart';

final driverProvider = ChangeNotifierProvider((ref) => DriverProvider());

class DriverProvider extends ChangeNotifier {
  // Text controllers
  final name = TextEditingController();
  final phone = TextEditingController();
  final license = TextEditingController();
  final model = TextEditingController();
  final year = TextEditingController();
  final passengers = TextEditingController();
  final color = TextEditingController();
  final plate = TextEditingController();
  final board = TextEditingController();
  final tin = TextEditingController();
  final businessLicenseController = TextEditingController();
  final insuranceCertificateController = TextEditingController();

  // Files
  File? vehiclePhoto;
  File? businessLicense;
  File? insuranceCertificate;

  Future<String?> submit() async {
    final data = {
      'name': name.text,
      'phone': phone.text,
      'license': license.text,
      'model': model.text,
      'year': year.text,
      'passengers': passengers.text,
      'color': color.text,
      'plate': plate.text,
      'board': board.text,
      'tin': tin.text,
      'vehiclePhoto': vehiclePhoto,
      'businessLicense': businessLicense,
      'insuranceCertificate': insuranceCertificate,
    };

    return await DriverService.registerDriver(data);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    license.dispose();
    model.dispose();
    year.dispose();
    passengers.dispose();
    color.dispose();
    plate.dispose();
    board.dispose();
    tin.dispose();
    businessLicenseController.dispose();
    insuranceCertificateController.dispose();
    super.dispose();
  }
}
