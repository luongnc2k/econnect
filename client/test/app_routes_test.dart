import 'package:client/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher role maps to teacher home route', () {
    expect(AppRoutes.homeForRole('teacher'), AppRoutes.teacherHome);
  });

  test('student and unknown roles map to student home route', () {
    expect(AppRoutes.homeForRole('student'), AppRoutes.studentHome);
    expect(AppRoutes.homeForRole('tutor'), AppRoutes.studentHome);
    expect(AppRoutes.homeForRole(null), AppRoutes.studentHome);
  });
}
