enum UserRole { tutor, student }

extension UserRoleX on UserRole {
  String get value => this == UserRole.tutor ? 'tutor' : 'student';

  static UserRole fromString(String s) {
    final v = s.toLowerCase();
    if (v == 'tutor') return UserRole.tutor;
    return UserRole.student;
  }
}

class User {
  final String id;
  final String fullName;
  final String emailOrPhone;
  final UserRole role;

  const User({
    required this.id,
    required this.fullName,
    required this.emailOrPhone,
    required this.role,
  });
}
