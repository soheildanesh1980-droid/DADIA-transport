class AuthSession {
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  bool get isValid {
    if (accessToken.isEmpty) return false;
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(DateTime.now());
  }
}
