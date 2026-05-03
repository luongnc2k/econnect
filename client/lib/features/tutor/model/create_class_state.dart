class CreateClassState {
  final bool isSubmitting;
  final String? error;
  final bool success;

  const CreateClassState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  CreateClassState copyWith({
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool? success,
  }) => CreateClassState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: clearError ? null : (error ?? this.error),
    success: success ?? this.success,
  );
}
