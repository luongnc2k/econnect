import 'package:client/features/auth/model/user_model.dart';

class StudentMyProfileModel extends UserModel {
  final String? englishLevel;
  final String? learningGoal;
  final String? bankName;
  final String? bankBin;
  final String? bankAccountNumber;
  final String? bankAccountHolder;
  final int totalLessons;
  final double? averageScore;

  bool get hasBankAccount =>
      _hasValue(bankName) &&
      _hasValue(bankBin) &&
      _hasValue(bankAccountNumber) &&
      _hasValue(bankAccountHolder);

  StudentMyProfileModel({
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
    this.englishLevel,
    this.learningGoal,
    this.bankName,
    this.bankBin,
    this.bankAccountNumber,
    this.bankAccountHolder,
    this.totalLessons = 0,
    this.averageScore,
  });

  factory StudentMyProfileModel.fromMap(Map<String, dynamic> map) {
    return StudentMyProfileModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'] ?? '',
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: map['role'] ?? 'student',
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
      englishLevel: map['english_level'] as String?,
      learningGoal: map['learning_goal'] as String?,
      bankName: map['bank_name'] as String?,
      bankBin: map['bank_bin'] as String?,
      bankAccountNumber: map['bank_account_number'] as String?,
      bankAccountHolder: map['bank_account_holder'] as String?,
      totalLessons: int.tryParse(map['total_lessons']?.toString() ?? '0') ?? 0,
      averageScore: map['average_score'] == null
          ? null
          : (map['average_score'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'english_level': englishLevel,
      'learning_goal': learningGoal,
      'bank_name': bankName,
      'bank_bin': bankBin,
      'bank_account_number': bankAccountNumber,
      'bank_account_holder': bankAccountHolder,
      'total_lessons': totalLessons,
      'average_score': averageScore,
    });
    return map;
  }

  @override
  StudentMyProfileModel copyWith({
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
    String? englishLevel,
    String? learningGoal,
    String? bankName,
    String? bankBin,
    String? bankAccountNumber,
    String? bankAccountHolder,
    int? totalLessons,
    double? averageScore,
  }) {
    return StudentMyProfileModel(
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
      englishLevel: englishLevel ?? this.englishLevel,
      learningGoal: learningGoal ?? this.learningGoal,
      bankName: bankName ?? this.bankName,
      bankBin: bankBin ?? this.bankBin,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      totalLessons: totalLessons ?? this.totalLessons,
      averageScore: averageScore ?? this.averageScore,
    );
  }

  static bool _hasValue(String? value) => (value ?? '').trim().isNotEmpty;
}
