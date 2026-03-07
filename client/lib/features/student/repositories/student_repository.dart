import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class StudentRepository {
  List<ClassSession> getClasses();
  List<TeacherPreview> getFeaturedTeachers();
}

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => MockStudentRepository(),
);

// ─── Mock implementation ──────────────────────────────────────────────────────

class MockStudentRepository implements StudentRepository {
  @override
  List<ClassSession> getClasses() => _mockClasses;

  @override
  List<TeacherPreview> getFeaturedTeachers() => mockTeachers;
}

const _mockClasses = [
  ClassSession(
    title: 'Luyện nói Business English',
    location: 'HighLand Coffee Cầu Giấy',
    teacherName: 'Alexander Ng',
    timeText: '18:30 Hôm nay',
    priceText: '120.000đ',
    statusText: 'OPEN',
    countdownText: 'Còn 3 chỗ',
    tags: ['Kinh doanh', 'Giao tiếp'],
    description:
        'Buổi luyện tập giao tiếp tiếng Anh trong môi trường kinh doanh. '
        'Thảo luận case study thực tế, roleplay tình huống thương lượng và thuyết trình.',
    dateText: 'Hôm nay, 05/03',
    slotText: '3/6 đã đăng ký',
    levelText: 'Intermediate+',
    teacherRating: 4.8,
    teacherSessionCount: 150,
    enrolledInitials: ['M', 'T', 'L'],
    extraEnrolled: 3,
  ),
  ClassSession(
    title: 'IELTS Speaking Practice',
    location: 'The Coffee House Hoàn Kiếm',
    teacherName: 'Sarah Johnson',
    timeText: '09:00 Ngày mai',
    priceText: '150.000đ',
    statusText: 'OPEN',
    countdownText: 'Còn 2 chỗ',
    tags: ['IELTS', 'Speaking'],
    description:
        'Luyện tập kỹ năng nói IELTS theo format thực tế. '
        'Tập trung vào Part 2 và Part 3, phản hồi chi tiết từ giảng viên có kinh nghiệm.',
    dateText: 'Ngày mai, 06/03',
    slotText: '4/6 đã đăng ký',
    levelText: 'Upper-Intermediate',
    teacherRating: 4.9,
    teacherSessionCount: 230,
    enrolledInitials: ['A', 'B', 'C'],
    extraEnrolled: 1,
  ),
];

const mockTeachers = [
  TeacherPreview(
    name: 'James Wilson',
    subtitle: 'Giảng viên giao tiếp và phát âm',
    rating: 4.9,
    reviewCount: 128,
    specialties: ['Pronunciation', 'Business English', 'IELTS'],
    badgeText: 'Expert',
  ),
  TeacherPreview(
    name: 'Anna Lee',
    subtitle: 'Chuyên luyện phản xạ giao tiếp cho người đi làm',
    rating: 4.8,
    reviewCount: 96,
    specialties: ['Speaking', 'Communication'],
    badgeText: 'Top Rated',
  ),
];
