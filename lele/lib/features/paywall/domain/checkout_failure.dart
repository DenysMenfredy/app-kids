/// Thrown with a user-presentable pt-BR message when checkout can't start.
class CheckoutFailure implements Exception {
  const CheckoutFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
