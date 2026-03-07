import 'dart:convert';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String token; // client-only — từ auth response, không có trong DB

  // Constructor
  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    required this.token,
  });

  // Tạo một bản sao của UserModel với các trường có thể được cập nhật
  UserModel copyWith({
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
  }) {
    return UserModel(
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
    );
  }

  // Chuyển đổi UserModel thành Map để dễ dàng lưu trữ hoặc truyền qua mạng
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role,
      'is_active': isActive,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'token': token,
    };
  }

  // Tạo một UserModel từ Map, thường được sử dụng khi nhận dữ liệu từ API hoặc lưu trữ
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'] ?? '',
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: map['role'] ?? '',
      isActive: map['is_active'] ?? true,
      lastLoginAt: map['last_login_at'] != null ? DateTime.tryParse(map['last_login_at']) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
      token: map['token'] ?? '',
    );
  }

  // Chuyển đổi UserModel thành JSON string để lưu trữ hoặc truyền qua mạng
  String toJson() => json.encode(toMap());

  // Tạo một UserModel từ JSON string, thường được sử dụng khi nhận dữ liệu từ API hoặc lưu trữ
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  // Override toString để dễ dàng debug và log thông tin người dùng
  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, fullName: $fullName, role: $role, isActive: $isActive)';
  }

  // Override == và hashCode để so sánh UserModel dựa trên id, email và token
  @override
  bool operator ==(covariant UserModel other) {
    if (identical(this, other)) return true;
    return other.id == id && other.email == email && other.token == token;
  }

  // Override hashCode để đảm bảo rằng các đối tượng UserModel có cùng id, email và token sẽ có cùng hash code
  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ token.hashCode;
}
