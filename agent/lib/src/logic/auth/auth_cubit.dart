import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../backend.dart';
import '../../repositories/auth_repository.dart';
import '../../models/user.dart';
import '../cache/session_wipe.dart';
import 'auth_state.dart';

class AuthCubit extends HydratedCubit<AuthState> {
  final AuthRepository _authRepository;
  final Backend _backend;

  /// Called after session data is wiped (sign-in / sign-out) so holders of
  /// in-memory session state (e.g. DownloadsCubit) can reset. Wired in main.
  Future<void> Function()? onSessionReset;

  AuthCubit(this._authRepository, this._backend) : super(AuthState()) {
    _authRepository.apiClient.onUnauthorized = forceLogout;
    _authRepository.apiClient.onRefresh = _tryRefresh;
  }

  String? get token => _authRepository.apiClient.token;

  Future<bool> _tryRefresh() async {
    try {
      await _authRepository.refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    emit(state.copyWith(status: AuthStatus.authenticating));
    try {
      await _authRepository.login(
        email,
        password,
        deviceId: _backend.deviceId,
        deviceType: _backend.deviceType,
      );
      // Zero-cache policy: a new sign-in starts clean (previous account's
      // downloads/positions must never leak across).
      await SessionWipe.wipeAll();
      await onSessionReset?.call();
      final user = await _authRepository.getCurrentUser();
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      emit(
        state.copyWith(status: AuthStatus.failure, errorMessage: e.toString()),
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
        deviceId: _backend.deviceId,
        deviceType: _backend.deviceType,
      );
      await SessionWipe.wipeAll();
      await onSessionReset?.call();
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
    // Zero-cache policy: signing out deletes everything downloaded/cached.
    await SessionWipe.wipeAll();
    await onSessionReset?.call();
    emit(AuthState(status: AuthStatus.unauthenticated));
  }

  /// Applies a freshly fetched user object (e.g. after profile edits).
  void updateUser(User user) {
    emit(state.copyWith(user: user));
  }

  void forceLogout() {
    _authRepository.apiClient.clearToken();
    // Best-effort wipe on forced logout (sync callback): stale session data
    // must not survive a dead session.
    SessionWipe.wipeAll();
    onSessionReset?.call();
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
      if (json['refresh_token'] != null) {
        _authRepository.setRefreshToken(json['refresh_token'] as String);
      }

      return AuthState(status: status, user: user);
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
      'refresh_token': _authRepository.refreshToken,
    };
  }
}