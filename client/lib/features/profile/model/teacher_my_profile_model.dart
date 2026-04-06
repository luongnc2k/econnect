import 'package:client/features/auth/model/user_model.dart';

class TeacherMyProfileModel extends UserModel {
  final String? specialization;
  final int yearsOfExperience;
  final double rating;
  final int totalStudents;
  final String? bio;
  final double? hourlyRate;
  final List<String> certifications;
  final List<String> verificationDocs;

  TeacherMyProfileModel({
    required super.id,
    required super.email,
    required super.fullName,
    super.phone,
    super.avatarUrl,
    required super.role,
    required super.isActive,
    super.lastLoginAt,
    super.createdAt,
    super.updatedAt,
    required super.token,
    this.specialization,
    this.yearsOfExperience = 0,
    this.rating = 0,
    this.totalStudents = 0,
    this.bio,
    this.hourlyRate,
    this.certifications = const [],
    this.verificationDocs = const [],
  });

  factory TeacherMyProfileModel.fromMap(Map<String, dynamic> map) {
    return TeacherMyProfileModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'] ?? '',
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: map['role'] ?? 'teacher',
      isActive: map['is_active'] ?? true,
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.tryParse(map['last_login_at'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'])
          : null,
      token: map['token'] ?? '',
      specialization: map['specialization'] as String?,
      yearsOfExperience:
          int.tryParse(map['years_of_experience']?.toString() ?? '0') ?? 0,
      rating: map['rating'] == null ? 0 : (map['rating'] as num).toDouble(),
      totalStudents:
          int.tryParse(map['total_students']?.toString() ?? '0') ?? 0,
      bio: map['bio'] as String?,
      hourlyRate: map['hourly_rate'] == null
          ? null
          : (map['hourly_rate'] as num).toDouble(),
      certifications: (map['certifications'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      verificationDocs: (map['verification_docs'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'specialization': specialization,
      'years_of_experience': yearsOfExperience,
      'rating': rating,
      'total_students': totalStudents,
      'bio': bio,
      'hourly_rate': hourlyRate,
      'certifications': certifications,
      'verification_docs': verificationDocs,
    });
    return map;
  }

  @override
  TeacherMyProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? role,
    bool? isActive,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? token,
    String? specialization,
    int? yearsOfExperience,
    double? rating,
    int? totalStudents,
    String? bio,
    double? hourlyRate,
    List<String>? certifications,
    List<String>? verificationDocs,
  }) {
    return TeacherMyProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      token: token ?? this.token,
      specialization: specialization ?? this.specialization,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      rating: rating ?? this.rating,
      totalStudents: totalStudents ?? this.totalStudents,
      bio: bio ?? this.bio,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      certifications: certifications ?? this.certifications,
      verificationDocs: verificationDocs ?? this.verificationDocs,
    );
  }
}
