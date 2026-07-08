import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../repositories/auth_repository.dart';
import '../../models/user.dart';
import 'auth_state.dart';

class AuthCubit extends HydratedCubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(AuthState()) {
    _authRepository.apiClient.onUnauthorized = forceLogout;
  }

  String? get token => _authRepository.apiClient.token;

  Future<void> login(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      await _authRepository.login(email, password);
      final user = await _authRepository.getCurrentUser();
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      final msg = e.toString();
      String errorMessage;
      if (msg.contains('Device limit exceeded') || msg.contains('429')) {
        errorMessage = msg;
      } else {
        errorMessage = msg;
      }
      emit(
        state.copyWith(status: AuthStatus.failure, errorMessage: errorMessage),
      );
    }
  }

  Future<void> register(Map<String, dynamic> data) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      await _authRepository.register(data);
      await _authRepository.login(
        data['email'],
        data['password'],
      );
      final user = await _authRepository.getCurrentUser();
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (_) {}
    emit(AuthState(status: AuthStatus.unauthenticated));
  }

  void forceLogout() {
    _authRepository.apiClient.clearToken();
    emit(AuthState(status: AuthStatus.unauthenticated));
  }

  @override
  AuthState? fromJson(Map<String, dynamic> json) {
    try {
      final statusStr = json['status'] as String?;
      final status = AuthStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => AuthStatus.unauthenticated,
      );
      
      // If the app was stuck authenticating, reset to unauthenticated
      if (status == AuthStatus.authenticating) {
        return AuthState(status: AuthStatus.unauthenticated);
      }
      
      final userJson = json['user'] as Map<String, dynamic>?;
      final user = userJson != null ? User.fromJson(userJson) : null;

      // Re-set token in apiClient if authenticated
      if (status == AuthStatus.authenticated && json['token'] != null) {
        _authRepository.apiClient.setToken(json['token'] as String);
      }

      return AuthState(
        status: status,
        user: user,
      );
    } catch (e) {
      return AuthState(status: AuthStatus.unauthenticated);
    }
  }

  @override
  Map<String, dynamic>? toJson(AuthState state) {
    return {
      'status': state.status.name,
      'user': state.user?.toJson(),
      'token': _authRepository.apiClient.token,
    };
  }
}
