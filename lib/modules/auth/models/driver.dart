import 'dart:io';

class Driver {
  String name;
  String phone;
  String license;
  String model;
  String year;
  String passengers;
  String color;
  String plate;
  String board;
  String tin;
  String code;
  File? vehiclePhoto;
  File? businessLicense;
  File? insuranceCertificate;

  Driver({
    required this.name,
    required this.phone,
    required this.license,
    required this.model,
    required this.year,
    required this.code,
    required this.passengers,
    required this.color,
    required this.plate,
    required this.board,
    required this.tin,
    this.vehiclePhoto,
    this.businessLicense,
    this.insuranceCertificate,
  });
}
