import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/enrolled_student_preview.dart';
import 'package:client/features/student/model/teacher_preview.dart';

class ManualTestMocks {
  static const enabled =
      bool.fromEnvironment('ENABLE_MANUAL_TEST_MOCKS', defaultValue: false);

  static const mockClasses = [
    ClassSession(
      id: 'a1b2c3d4-e5f6-7890-abcd-111122223333',
      classCode: 'CLS-250305-A1B2',
      teacherId: 'teacher-james-wilson',
      title: 'Luyen noi Business English',
      location: 'HighLand Coffee Cau Giay',
      teacherName: 'Alexander Ng',
      timeText: '18:30 Hom nay',
      priceText: '120.000d',
      statusText: 'OPEN',
      countdownText: 'Con 3 cho',
      tags: ['Kinh doanh', 'Giao tiep'],
      description:
          'Buoi luyen tap giao tiep tieng Anh trong moi truong kinh doanh. '
          'Thao luan case study thuc te, roleplay tinh huong thuong luong va thuyet trinh.',
      dateText: 'Hom nay, 05/03',
      slotText: '3/6 da dang ky',
      levelText: 'Intermediate+',
      teacherRating: 0.0,
      teacherSessionCount: 150,
      enrolledStudents: [
        EnrolledStudentPreview(id: 'student-minh-tran', initials: 'M'),
        EnrolledStudentPreview(id: 'student-thao-nguyen', initials: 'T'),
        EnrolledStudentPreview(id: 'student-linh-le', initials: 'L'),
      ],
      enrolledInitials: ['M', 'T', 'L'],
      extraEnrolled: 3,
    ),
    ClassSession(
      id: 'b2c3d4e5-f6a7-8901-bcde-222233334444',
      classCode: 'CLS-250306-B2C3',
      teacherId: 'teacher-anna-lee',
      title: 'IELTS Speaking Practice',
      location: 'The Coffee House Hoan Kiem',
      teacherName: 'Sarah Johnson',
      timeText: '09:00 Ngay mai',
      priceText: '150.000d',
      statusText: 'OPEN',
      countdownText: 'Con 2 cho',
      tags: ['IELTS', 'Speaking'],
      description:
          'Luyen tap ky nang noi IELTS theo format thuc te. '
          'Tap trung vao Part 2 va Part 3, phan hoi chi tiet tu giang vien co kinh nghiem.',
      dateText: 'Ngay mai, 06/03',
      slotText: '4/6 da dang ky',
      levelText: 'Upper-Intermediate',
      teacherRating: 0.0,
      teacherSessionCount: 230,
      enrolledStudents: [
        EnrolledStudentPreview(id: 'student-an-phan', initials: 'A'),
        EnrolledStudentPreview(id: 'student-binh-vo', initials: 'B'),
        EnrolledStudentPreview(id: 'student-chi-do', initials: 'C'),
      ],
      enrolledInitials: ['A', 'B', 'C'],
      extraEnrolled: 1,
    ),
  ];

  static const mockTeachers = [
    TeacherPreview(
      id: 'teacher-james-wilson',
      name: 'James Wilson',
      subtitle: 'Giang vien giao tiep va phat am',
      rating: 0.0,
      reviewCount: 128,
      specialties: ['Pronunciation', 'Business English', 'IELTS'],
      badgeText: 'Expert',
    ),
    TeacherPreview(
      id: 'teacher-anna-lee',
      name: 'Anna Lee',
      subtitle: 'Chuyen luyen phan xa giao tiep cho nguoi di lam',
      rating: 0.0,
      reviewCount: 96,
      specialties: ['Speaking', 'Communication'],
      badgeText: 'Top Rated',
    ),
  ];

  static final _mockUsers = <UserModel>[
    UserModel(
      id: 'teacher-james-wilson',
      email: 'james.wilson@example.com',
      fullName: 'James Wilson',
      phone: '0901000001',
      avatarUrl: null,
      role: 'teacher',
      isActive: true,
      token: '',
    ),
    UserModel(
      id: 'teacher-anna-lee',
      email: 'anna.lee@example.com',
      fullName: 'Anna Lee',
      phone: '0901000002',
      avatarUrl: null,
      role: 'teacher',
      isActive: true,
      token: '',
    ),
    UserModel(
      id: 'student-minh-tran',
      email: 'minh.tran@example.com',
      fullName: 'Minh Tran',
      phone: '0902000001',
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
    ),
    UserModel(
      id: 'student-thao-nguyen',
      email: 'thao.nguyen@example.com',
      fullName: 'Thao Nguyen',
      phone: '0902000002',
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
    ),
    UserModel(
      id: 'student-linh-le',
      email: 'linh.le@example.com',
      fullName: 'Linh Le',
      phone: '0902000003',
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
    ),
    UserModel(
      id: 'student-an-phan',
      email: 'an.phan@example.com',
      fullName: 'An Phan',
      phone: '0902000004',
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
    ),
    UserModel(
      id: 'student-binh-vo',
      email: 'binh.vo@example.com',
      fullName: 'Binh Vo',
      phone: '0902000005',
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
    ),
    UserModel(
      id: 'student-chi-do',
      email: 'chi.do@example.com',
      fullName: 'Chi Do',
      phone: '0902000006',
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
    ),
  ];

  static UserModel? findProfile(String userId) {
    switch (userId) {
      case 'teacher-james-wilson':
        return TeacherMyProfileModel(
          id: userId,
          email: 'james.wilson@example.com',
          fullName: 'James Wilson',
          phone: '0901000001',
          avatarUrl: null,
          role: 'teacher',
          isActive: true,
          token: '',
          specialization: 'Business English',
          bankName: 'Vietcombank',
          bankAccountNumber: '0011002233445',
          bankAccountHolder: 'JAMES WILSON',
          yearsOfExperience: 7,
          rating: 0.0,
          totalStudents: 128,
          bio: 'Chuyen day giao tiep va phat am cho nguoi di lam.',
          hourlyRate: 250000,
          certifications: const ['TESOL', 'IELTS Trainer'],
        );
      case 'teacher-anna-lee':
        return TeacherMyProfileModel(
          id: userId,
          email: 'anna.lee@example.com',
          fullName: 'Anna Lee',
          phone: '0901000002',
          avatarUrl: null,
          role: 'teacher',
          isActive: true,
          token: '',
          specialization: 'Speaking Coach',
          bankName: 'Techcombank',
          bankAccountNumber: '1903004455667',
          bankAccountHolder: 'ANNA LEE',
          yearsOfExperience: 5,
          rating: 0.0,
          totalStudents: 96,
          bio: 'Tap trung luyen phan xa giao tiep va phat am tu nhien.',
          hourlyRate: 220000,
          certifications: const ['TEFL', 'Communication Coaching'],
        );
      case 'student-minh-tran':
        return StudentMyProfileModel(
          id: userId,
          email: 'minh.tran@example.com',
          fullName: 'Minh Tran',
          phone: '0902000001',
          avatarUrl: null,
          role: 'student',
          isActive: true,
          token: '',
          englishLevel: 'B1',
          learningGoal: 'Improve business speaking',
          totalLessons: 18,
          averageScore: 7.2,
        );
      case 'student-thao-nguyen':
        return StudentMyProfileModel(
          id: userId,
          email: 'thao.nguyen@example.com',
          fullName: 'Thao Nguyen',
          phone: '0902000002',
          avatarUrl: null,
          role: 'student',
          isActive: true,
          token: '',
          englishLevel: 'A2',
          learningGoal: 'Speak confidently in daily situations',
          totalLessons: 9,
          averageScore: 6.8,
        );
      case 'student-linh-le':
        return StudentMyProfileModel(
          id: userId,
          email: 'linh.le@example.com',
          fullName: 'Linh Le',
          phone: '0902000003',
          avatarUrl: null,
          role: 'student',
          isActive: true,
          token: '',
          englishLevel: 'B2',
          learningGoal: 'Prepare for IELTS speaking',
          totalLessons: 24,
          averageScore: 7.8,
        );
      case 'student-an-phan':
        return StudentMyProfileModel(
          id: userId,
          email: 'an.phan@example.com',
          fullName: 'An Phan',
          phone: '0902000004',
          avatarUrl: null,
          role: 'student',
          isActive: true,
          token: '',
          englishLevel: 'B1',
          learningGoal: 'Improve pronunciation',
          totalLessons: 14,
          averageScore: 7.1,
        );
      case 'student-binh-vo':
        return StudentMyProfileModel(
          id: userId,
          email: 'binh.vo@example.com',
          fullName: 'Binh Vo',
          phone: '0902000005',
          avatarUrl: null,
          role: 'student',
          isActive: true,
          token: '',
          englishLevel: 'A2',
          learningGoal: 'Build basic communication skills',
          totalLessons: 7,
          averageScore: 6.5,
        );
      case 'student-chi-do':
        return StudentMyProfileModel(
          id: userId,
          email: 'chi.do@example.com',
          fullName: 'Chi Do',
          phone: '0902000006',
          avatarUrl: null,
          role: 'student',
          isActive: true,
          token: '',
          englishLevel: 'B2',
          learningGoal: 'Advance IELTS speaking band',
          totalLessons: 21,
          averageScore: 7.6,
        );
      default:
        return null;
    }
  }

  static List<UserModel> searchUsers(String keyword) {
    final normalized = keyword.toLowerCase();
    return _mockUsers
        .where(
          (user) =>
              user.fullName.toLowerCase().contains(normalized) ||
              (user.phone ?? '').contains(keyword),
        )
        .toList();
  }
}
