import 'dart:convert';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/features/notifications/model/app_notification.dart';
import 'package:client/features/notifications/model/notifications_page.dart';
import 'package:client/features/notifications/model/tutor_teaching_confirmation_result.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final notificationsRemoteRepositoryProvider = Provider<NotificationsRemoteRepository>(
  (_) => NotificationsRemoteRepository(),
);

class NotificationsRemoteRepository {
  Future<Either<AppFailure, List<AppNotification>>> getNotifications({
    required String token,
    int limit = 20,
    int offset = 0,
    String? notificationType,
    bool unreadOnly = false,
  }) async {
    try {
      final queryParameters = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (notificationType != null && notificationType.isNotEmpty) {
        queryParameters['type'] = notificationType;
      }
      if (unreadOnly) {
        queryParameters['unread_only'] = 'true';
      }

      final uri = Uri.parse('${ServerConstant.serverURL}/notifications').replace(
        queryParameters: queryParameters,
      );
      final response = await http.get(uri, headers: {'x-auth-token': token});
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }

      final body = jsonDecode(response.body) as List<dynamic>;
      final notifications = body
          .map((item) => AppNotification.fromMap(item as Map<String, dynamic>))
          .toList();
      return Right(notifications);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, NotificationsPage>> getNotificationsPage({
    required String token,
    int limit = 20,
    String? cursor,
    String? notificationType,
    bool unreadOnly = false,
  }) async {
    try {
      final queryParameters = <String, String>{
        'limit': '$limit',
      };
      if (cursor != null && cursor.isNotEmpty) {
        queryParameters['cursor'] = cursor;
      }
      if (notificationType != null && notificationType.isNotEmpty) {
        queryParameters['type'] = notificationType;
      }
      if (unreadOnly) {
        queryParameters['unread_only'] = 'true';
      }

      final uri = Uri.parse('${ServerConstant.serverURL}/notifications/cursor').replace(
        queryParameters: queryParameters,
      );
      final response = await http.get(uri, headers: {'x-auth-token': token});
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(NotificationsPage.fromMap(body));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, int>> getUnreadCount({
    required String token,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/notifications/unread-count');
      final response = await http.get(uri, headers: {'x-auth-token': token});
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Right((body['unread_count'] as num?)?.toInt() ?? 0);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, String>> registerPushToken({
    required String token,
    required String pushToken,
    required String platform,
    String? deviceLabel,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/notifications/push-tokens');
      final response = await http.post(
        uri,
        headers: {
          'x-auth-token': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': pushToken,
          'platform': platform,
          if (deviceLabel != null && deviceLabel.isNotEmpty) 'device_label': deviceLabel,
        }),
      );
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(body['message']?.toString() ?? 'Đã đăng ký FCM token');
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, String>> unregisterPushToken({
    required String token,
    required String pushToken,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/notifications/push-tokens/unregister');
      final response = await http.post(
        uri,
        headers: {
          'x-auth-token': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': pushToken}),
      );
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(body['message']?.toString() ?? 'Đã hủy đăng ký FCM token');
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, AppNotification>> markAsRead({
    required String token,
    required String notificationId,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/notifications/$notificationId/read');
      final response = await http.post(uri, headers: {'x-auth-token': token});
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(AppNotification.fromMap(body));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, TutorTeachingConfirmationResult>> confirmTeaching({
    required String token,
    required String classId,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/payments/classes/$classId/confirm-teaching');
      final response = await http.post(uri, headers: {'x-auth-token': token});
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(TutorTeachingConfirmationResult.fromMap(body));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  AppFailure _decodeFailure(http.Response response) {
    try {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return AppFailure(map['detail']?.toString() ?? 'Có lỗi xảy ra', response.statusCode);
    } catch (_) {
      return AppFailure('Có lỗi xảy ra', response.statusCode);
    }
  }
}
