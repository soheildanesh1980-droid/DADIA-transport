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

  DateTime? _parseExpiry(Map<String, dynamic> data) {
    final value = data['expiresAt'] ?? data['expires_at'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  AuthSession _setSession(Map<String, dynamic> data) {
    final accessToken = data['accessToken'] ?? data['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw Exception('AUTH_TOKEN_MISSING');
    }

    final refreshToken = data['refreshToken'] ?? data['refresh_token'];
    _session = AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken is String ? refreshToken : null,
      expiresAt: _parseExpiry(data),
    );
    _state = const AuthState.authenticated();
    return _session!;
  }

  Future<AuthSession> login(String phone, String password) async {
    _state = const AuthState.loading();
    try {
      return _setSession(await apiClient.login(phone, password));
    } catch (error) {
      _state = AuthState.error(error.toString());
      rethrow;
    }
  }

  Future<AuthSession> register(String phone, String password) async {
    _state = const AuthState.loading();
    try {
      return _setSession(await apiClient.register(phone, password));
    } catch (error) {
      _state = AuthState.error(error.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> me() => apiClient.me();

  void logout() {
    _session = null;
    apiClient.accessToken = null;
    _state = const AuthState.unauthenticated();
  }
}
