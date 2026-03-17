import 'package:client/features/tutor/model/topic_model.dart';

class CreateClassState {
  final List<TopicModel> topics;
  final bool isLoadingTopics;
  final bool isSubmitting;
  final String? error;
  final bool success;

  const CreateClassState({
    this.topics = const [],
    this.isLoadingTopics = false,
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  CreateClassState copyWith({
    List<TopicModel>? topics,
    bool? isLoadingTopics,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool? success,
  }) =>
      CreateClassState(
        topics: topics ?? this.topics,
        isLoadingTopics: isLoadingTopics ?? this.isLoadingTopics,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : (error ?? this.error),
        success: success ?? this.success,
      );
}
