import '../../domain/entities/user.dart';

class AuthState {
  final bool loading;
  final String? error;
  final bool loggedIn;
  final UserRole? role;

  const AuthState({
    required this.loading,
    required this.loggedIn,
    this.error,
    this.role,
  });

  factory AuthState.initial() => const AuthState(loading: false, loggedIn: false);

  AuthState copyWith({
    bool? loading,
    String? error,
    bool? loggedIn,
    UserRole? role,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      error: error,
      loggedIn: loggedIn ?? this.loggedIn,
      role: role ?? this.role,
    );
  }
}
