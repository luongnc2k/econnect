class AppFailure {
  final String message;
  final int? statusCode;

  AppFailure([
    this.message = 'Sorry, an unexpected error occurred!',
    this.statusCode,
  ]);

  bool get isAuthError => statusCode != null && statusCode! >= 400 && statusCode! < 500;

  @override
  String toString() => 'AppFailure(message: $message, statusCode: $statusCode)';
}
