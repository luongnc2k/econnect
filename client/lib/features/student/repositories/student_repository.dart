import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/enrolled_student_preview.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class StudentRepository {
  List<ClassSession> getClasses();
  List<TeacherPreview> getFeaturedTeachers();
}

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => MockStudentRepository(),
);

class MockStudentRepository implements StudentRepository {
  @override
  List<ClassSession> getClasses() => mockClasses;

  @override
  List<TeacherPreview> getFeaturedTeachers() => mockTeachers;
}

const mockClasses = [
  ClassSession(
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
    teacherRating: 4.8,
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
    teacherRating: 4.9,
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

const mockTeachers = [
  TeacherPreview(
    id: 'teacher-james-wilson',
    name: 'James Wilson',
    subtitle: 'Giang vien giao tiep va phat am',
    rating: 4.9,
    reviewCount: 128,
    specialties: ['Pronunciation', 'Business English', 'IELTS'],
    badgeText: 'Expert',
  ),
  TeacherPreview(
    id: 'teacher-anna-lee',
    name: 'Anna Lee',
    subtitle: 'Chuyen luyen phan xa giao tiep cho nguoi di lam',
    rating: 4.8,
    reviewCount: 96,
    specialties: ['Speaking', 'Communication'],
    badgeText: 'Top Rated',
  ),
];
