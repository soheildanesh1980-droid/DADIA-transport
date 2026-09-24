enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  loading,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? message;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.message,
  });

  const AuthState.authenticated()
      : status = AuthStatus.authenticated,
        message = null;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        message = null;

  const AuthState.loading()
      : status = AuthStatus.loading,
        message = null;

  AuthState.error(String value)
      : status = AuthStatus.error,
        message = value;
}
