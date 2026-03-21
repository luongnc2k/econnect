import 'dart:typed_data';

import 'package:client/core/providers/current_user_notifier.dart';
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
  CreateClassState build() {
    Future.microtask(_loadTopics);
    return const CreateClassState(isLoadingTopics: true);
  }

  Future<void> _loadTopics() async {
    final repo = ref.read(tutorRemoteRepositoryProvider);
    final result = await repo.getTopics();
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(isLoadingTopics: false, error: failure.message);
      case Right(value: final topics):
        state = state.copyWith(isLoadingTopics: false, topics: topics, clearError: true);
    }
  }

  Future<bool> submitClass({
    required String topicId,
    required String title,
    String? description,
    required String level,
    required String locationName,
    String? locationAddress,
    required DateTime startTime,
    required DateTime endTime,
    required int minParticipants,
    required int maxParticipants,
    required double price,
    String? thumbnailUrl,
    // thumbnail upload params
    Uint8List? thumbnailBytes,
    String? thumbnailFileName,
    String? thumbnailFilePath,
  }) async {
    final token = ref.read(currentUserProvider)?.token;
    if (token == null) {
      state = state.copyWith(error: 'Vui lòng đăng nhập lại');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    final repo = ref.read(tutorRemoteRepositoryProvider);

    // Upload thumbnail if provided
    String? finalThumbnailUrl = thumbnailUrl;
    if (thumbnailBytes != null && thumbnailFileName != null) {
      final uploadResult = await repo.uploadThumbnail(
        token: token,
        fileName: thumbnailFileName,
        fileBytes: thumbnailBytes,
        filePath: thumbnailFilePath,
      );
      switch (uploadResult) {
        case Left(value: final failure):
          state = state.copyWith(isSubmitting: false, error: failure.message);
          return false;
        case Right(value: final url):
          finalThumbnailUrl = url;
      }
    }

    // Build request body — send times as UTC ISO-8601
    final body = <String, dynamic>{
      'topic_id': topicId,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'level': level,
      'location_name': locationName,
      if (locationAddress != null && locationAddress.isNotEmpty)
        'location_address': locationAddress,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'min_participants': minParticipants,
      'max_participants': maxParticipants,
      'price': price,
      if (finalThumbnailUrl != null) 'thumbnail_url': finalThumbnailUrl,
    };

    final result = await repo.createClass(token, body);
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return false;
      case Right():
        state = state.copyWith(isSubmitting: false, success: true, clearError: true);
        return true;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}
