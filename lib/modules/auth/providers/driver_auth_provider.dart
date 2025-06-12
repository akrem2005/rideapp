import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/driver_code_service.dart';

class AuthState {
  final String? objectId;
  final bool isLoading;
  final String? error;

  AuthState({this.objectId, this.isLoading = false, this.error});

  AuthState copyWith({String? objectId, bool? isLoading, String? error}) {
    return AuthState(
      objectId: objectId ?? this.objectId,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final DriverAuthService _authService;

  AuthNotifier(this._authService) : super(AuthState());

  Future<void> verifyOtp(String phone, String code) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _authService.verifyOtp(phone, code);

    if (result['success']) {
      state = state.copyWith(objectId: result['objectId'], isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, error: result['error']);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(DriverAuthService());
});
