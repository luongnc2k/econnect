import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/view/widgets/my_profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile header normalizes backend static avatar url', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyProfileHeader(
            profile: UserModel(
              id: 'user-1',
              email: 'user@example.com',
              fullName: 'User Demo',
              avatarUrl: 'http://localhost:8000/static/user-avatars/avatar.jpg',
              role: 'student',
              isActive: true,
              token: 'token-123',
            ),
          ),
        ),
      ),
    );

    final imageLoadException = tester.takeException();
    expect(imageLoadException, anyOf(isNull, isA<NetworkImageLoadException>()));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final image = avatar.backgroundImage;

    expect(image, isA<NetworkImage>());
    expect(
      (image as NetworkImage).url,
      'http://10.0.2.2:8000/static/user-avatars/avatar.jpg',
    );
  });
}
