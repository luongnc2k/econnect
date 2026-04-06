class ServerConstant {
  static const String serverURL = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
