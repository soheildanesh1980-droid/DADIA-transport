import '../network/api_client.dart';
import 'auth_session.dart';
import 'auth_state.dart';

class AuthService {
  final ApiClient apiClient;

  AuthSession? _session;
  AuthState _state = const AuthState();

  AuthService(this.apiClient);

  AuthSession? get session => _session;
  AuthState get state => _state;
  bool get isAuthenticated => _session?.isValid ?? false;

  Future<AuthSession> login(
    String phone,
    String password,
  ) async {
    _state = const AuthState.loading();

    try {
      final data = await apiClient.login(phone, password);

      final accessToken =
          data['accessToken'] ?? data['access_token'];

      if (accessToken is! String || accessToken.isEmpty) {
        throw Exception('AUTH_TOKEN_MISSING');
      }

      final refreshToken =
          data['refreshToken'] ?? data['refresh_token'];

      final expiresAtValue =
          data['expiresAt'] ?? data['expires_at'];

      DateTime? expiresAt;
      if (expiresAtValue is String) {
        expiresAt = DateTime.tryParse(expiresAtValue);
      }

      _session = AuthSession(
        accessToken: accessToken,
        refreshToken:
            refreshToken is String ? refreshToken : null,
        expiresAt: expiresAt,
      );

      _state = const AuthState.authenticated();
      return _session!;
    } catch (error) {
      _state = AuthState.error(error.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> me() {
    return apiClient.me();
  }

  void logout() {
    _session = null;
    apiClient.accessToken = null;
    _state = const AuthState.unauthenticated();
  }
}
