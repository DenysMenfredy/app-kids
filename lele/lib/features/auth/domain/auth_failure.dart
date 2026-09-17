/// Thrown by repositories with a message safe to show the user (pt-BR).
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
