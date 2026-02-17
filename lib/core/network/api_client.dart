/// IO/HTTP client for making API calls.
/// 
/// This class abstracts away the details of making HTTP requests and handling responses,
/// allowing you to easily interact with APIs in your application.

import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'endpoints.dart';

class ApiClient {
  ApiClient._();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: Endpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
}
