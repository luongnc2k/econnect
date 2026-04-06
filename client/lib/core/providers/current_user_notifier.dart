import 'package:client/features/auth/model/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'current_user_notifier.g.dart';

@Riverpod(keepAlive: true)
class CurrentUserNotifier extends _$CurrentUserNotifier {
  @override
  UserModel? build() {
    return null;
  }

  void addUser(UserModel? user) {
    state = user;
  }

  void setUser(UserModel? user) {
    state = user;
  }

  void clearUser() {
    state = null;
  }

  void updateUser({
    String? fullName,
    String? phone,
    String? avatarUrl,
    DateTime? lastLoginAt,
    DateTime? updatedAt,
  }) {
    final current = state;
    if (current == null) return;

    state = current.copyWith(
      fullName: fullName,
      phone: phone,
      avatarUrl: avatarUrl,
      lastLoginAt: lastLoginAt,
      updatedAt: updatedAt,
    );
  }
}



