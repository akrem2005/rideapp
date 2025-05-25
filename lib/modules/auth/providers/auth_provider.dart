import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/auth_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier(AuthService());
});

class AuthNotifier extends StateNotifier<bool> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(false);

  Future<void> sendOtp(String phoneNumber) async {
    final success = await _authService.sendOtp(phoneNumber);
    state = success;
  }

  Future<bool> verifyOtp(String phoneNumber, String code) async {
    return await _authService.verifyOtp(phoneNumber, code);
  }
}
