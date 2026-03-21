import 'dart:convert';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/features/payments/model/payment_summary.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final paymentsRemoteRepositoryProvider = Provider<PaymentsRemoteRepository>(
  (_) => PaymentsRemoteRepository(),
);

class PaymentsRemoteRepository {
  Future<Either<AppFailure, PaymentTransactionStatus>> createJoinPayment({
    required String token,
    required String classId,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/payments/classes/$classId/join/request');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({}),
      );
      return _decodeTransactionResponse(response);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, PaymentTransactionStatus>> getTransactionStatus({
    required String token,
    required String transactionRef,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/payments/transactions/$transactionRef');
      final response = await http.get(uri, headers: {'x-auth-token': token});
      return _decodeTransactionResponse(response);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, PaymentSummary>> getSummaryByClassCode({
    required String token,
    required String classCode,
  }) async {
    try {
      final uri = Uri.parse(
        '${ServerConstant.serverURL}/payments/classes/by-code/${classCode.trim().toUpperCase()}/summary',
      );
      final response = await http.get(uri, headers: {'x-auth-token': token});
      if (response.statusCode != 200) {
        return Left(_decodeFailure(response));
      }
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(PaymentSummary.fromMap(map));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Either<AppFailure, PaymentTransactionStatus> _decodeTransactionResponse(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      return Left(_decodeFailure(response));
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return Right(PaymentTransactionStatus.fromMap(map));
  }

  AppFailure _decodeFailure(http.Response response) {
    try {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return AppFailure(map['detail']?.toString() ?? 'Co loi xay ra', response.statusCode);
    } catch (_) {
      return AppFailure('Co loi xay ra', response.statusCode);
    }
  }
}
