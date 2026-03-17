import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/tutor/model/enrolled_student.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

final enrolledStudentsProvider =
    FutureProvider.family<List<EnrolledStudent>, String>((ref, classId) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return [];

  final repo = ref.read(tutorRemoteRepositoryProvider);
  final result = await repo.getClassDetail(user.token, classId);
  switch (result) {
    case Left():
      return [];
    case Right(value: final students):
      return students;
  }
});
