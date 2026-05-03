import 'dart:typed_data';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/tutor/model/create_class_state.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

final createClassViewModelProvider =
    NotifierProvider<CreateClassViewModel, CreateClassState>(
      CreateClassViewModel.new,
    );

class CreateClassViewModel extends Notifier<CreateClassState> {
  @override
  CreateClassState build() => const CreateClassState();

  Future<PaymentTransactionStatus?> submitClass({
    required String topic,
    required String title,
    String? description,
    required String level,
    required String locationId,
    required DateTime startTime,
    required DateTime endTime,
    required int minParticipants,
    required int maxParticipants,
    required double price,
    String? thumbnailUrl,
    Uint8List? thumbnailBytes,
    String? thumbnailFileName,
    String? thumbnailFilePath,
    String? materialUrl,
    Uint8List? materialBytes,
    String? materialFileName,
    String? materialFilePath,
  }) async {
    final token = ref.read(currentUserProvider)?.token;
    if (token == null) {
      state = state.copyWith(error: 'Vui lòng đăng nhập lại');
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    final tutorRepo = ref.read(tutorRemoteRepositoryProvider);
    final paymentsRepo = ref.read(paymentsRemoteRepositoryProvider);

    String? finalThumbnailUrl = thumbnailUrl;
    if (thumbnailBytes != null && thumbnailFileName != null) {
      final uploadResult = await tutorRepo.uploadThumbnail(
        token: token,
        fileName: thumbnailFileName,
        fileBytes: thumbnailBytes,
        filePath: thumbnailFilePath,
      );
      switch (uploadResult) {
        case Left(value: final failure):
          state = state.copyWith(isSubmitting: false, error: failure.message);
          return null;
        case Right(value: final url):
          finalThumbnailUrl = url;
      }
    }

    String? finalMaterialUrl = materialUrl;
    if (materialBytes != null && materialFileName != null) {
      final uploadResult = await tutorRepo.uploadClassMaterial(
        token: token,
        fileName: materialFileName,
        fileBytes: materialBytes,
        filePath: materialFilePath,
      );
      switch (uploadResult) {
        case Left(value: final failure):
          state = state.copyWith(isSubmitting: false, error: failure.message);
          return null;
        case Right(value: final url):
          finalMaterialUrl = url;
      }
    }

    final body = <String, dynamic>{
      'topic': topic,
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      'level': level,
      'location_id': locationId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'min_participants': minParticipants,
      'max_participants': maxParticipants,
      'price': price,
      ...?switch (finalThumbnailUrl) {
        final String thumbnailUrl => {'thumbnail_url': thumbnailUrl},
        _ => null,
      },
      ...?switch (finalMaterialUrl) {
        final String materialUrl => {
          'material_url': materialUrl,
          if (materialFileName != null && materialFileName.trim().isNotEmpty)
            'material_file_name': materialFileName.trim(),
        },
        _ => null,
      },
    };

    final result = await paymentsRepo.createClassCreationPayment(
      token: token,
      classPayload: body,
    );
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return null;
      case Right(value: final payment):
        state = state.copyWith(
          isSubmitting: false,
          success: false,
          clearError: true,
        );
        return payment;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
