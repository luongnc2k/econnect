enum UserRole { student, tutor }

class UserModel {
  final String id;
  final String fullName;
  final DateTime dob;
  final String education;
  final String job;
  final String nationality;
  final String? bio;
  final String? avatarUrl;
  final UserRole role;

  final List<String>? certificates;
  final List<String>? degrees;
  final int? experienceYears;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.dob,
    required this.education,
    required this.job,
    required this.nationality,
    required this.role,
    this.bio,
    this.avatarUrl,
    this.certificates,
    this.degrees,
    this.experienceYears,
  });

  bool get isTutor => role == UserRole.tutor;

  UserModel copyWith({
    String? fullName,
    DateTime? dob,
    String? education,
    String? job,
    String? nationality,
    String? bio,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      education: education ?? this.education,
      job: job ?? this.job,
      nationality: nationality ?? this.nationality,
      role: role,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl,
      certificates: certificates,
      degrees: degrees,
      experienceYears: experienceYears,
    );
  }
}