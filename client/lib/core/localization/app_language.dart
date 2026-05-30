import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appSupportedLocales = <Locale>[Locale('en'), Locale('vi')];

enum AppLanguage {
  english('en', 'English', 'EN'),
  vietnamese('vi', 'Tiếng Việt', 'VI');

  const AppLanguage(this.languageCode, this.nativeLabel, this.shortLabel);

  final String languageCode;
  final String nativeLabel;
  final String shortLabel;

  Locale get locale => Locale(languageCode);

  static AppLanguage fromLocale(Locale locale) {
    return AppLanguage.values.firstWhere(
      (language) => language.languageCode == locale.languageCode,
      orElse: () => AppLanguage.english,
    );
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(
  AppLocaleNotifier.new,
);

final appStringsProvider = Provider<AppStrings>((ref) {
  final locale = ref.watch(appLocaleProvider);
  return AppStrings(locale.languageCode);
});

class AppLocaleNotifier extends Notifier<Locale> {
  static const _languageCodeKey = 'app-language-code';

  @override
  Locale build() => AppLanguage.vietnamese.locale;

  Future<void> loadSavedLocale() async {
    final preferences = await SharedPreferences.getInstance();
    final languageCode = preferences.getString(_languageCodeKey);
    if (languageCode != null) {
      state = _localeFor(languageCode);
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language.locale;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languageCodeKey, language.languageCode);
  }

  static Locale _localeFor(String? languageCode) {
    final code = languageCode?.toLowerCase().split(RegExp('[-_]')).first;
    if (code == AppLanguage.vietnamese.languageCode) {
      return AppLanguage.vietnamese.locale;
    }
    return AppLanguage.english.locale;
  }
}

class AppStrings {
  final String languageCode;

  const AppStrings(this.languageCode);

  bool get isVietnamese => languageCode == AppLanguage.vietnamese.languageCode;

  String text({required String en, required String vi}) =>
      isVietnamese ? vi : en;

  String get language => isVietnamese ? 'Ngôn ngữ' : 'Language';
  String get loginTitle => isVietnamese ? 'Đăng nhập' : 'Sign in';
  String get loginSubtitle =>
      isVietnamese ? 'Chào mừng bạn quay lại!' : 'Welcome back!';
  String get signupTitle => isVietnamese ? 'Đăng ký' : 'Sign up';
  String get signupSubtitle => isVietnamese
      ? 'Tạo tài khoản để bắt đầu học tập'
      : 'Create an account to start learning';
  String get name => isVietnamese ? 'Họ tên' : 'Name';
  String get email => 'Email';
  String get password => isVietnamese ? 'Mật khẩu' : 'Password';
  String get signIn => isVietnamese ? 'Đăng nhập' : 'Sign In';
  String get signUp => isVietnamese ? 'Đăng ký' : 'Sign Up';
  String get googleSignIn =>
      isVietnamese ? 'Đăng nhập với Google' : 'Sign in with Google';
  String get googleSignUp =>
      isVietnamese ? 'Đăng ký với Google' : 'Sign up with Google';
  String get dontHaveAccount =>
      isVietnamese ? 'Chưa có tài khoản? ' : "Don't have an account? ";
  String get alreadyHaveAccount =>
      isVietnamese ? 'Đã có tài khoản? ' : 'Already have an account? ';
  String get studentRole => isVietnamese ? 'Học viên' : 'Student';
  String get teacherRole => isVietnamese ? 'Gia sư' : 'Tutor';
  String get missingFields => isVietnamese
      ? 'Vui lòng nhập đầy đủ thông tin.'
      : 'Please complete all required fields.';
  String get accountCreated => isVietnamese
      ? 'Tạo tài khoản thành công. Vui lòng đăng nhập.'
      : 'Account created successfully. Please sign in.';

  String requiredField(String label) {
    return isVietnamese ? 'Vui lòng nhập $label.' : '$label is required.';
  }

  String get morningGreeting =>
      isVietnamese ? 'Chào buổi sáng,' : 'Good morning,';
  String get afternoonGreeting =>
      isVietnamese ? 'Chào buổi chiều,' : 'Good afternoon,';
  String get eveningGreeting =>
      isVietnamese ? 'Chào buổi tối,' : 'Good evening,';
  String get defaultStudentName => isVietnamese ? 'Bạn' : 'You';
  String get defaultTeacherName => isVietnamese ? 'Giảng viên' : 'Tutor';
  String get upcomingClassList =>
      isVietnamese ? 'Danh sách buổi học' : 'Upcoming classes';
  String get all => isVietnamese ? 'Tất cả' : 'All';
  String get featuredTeachers =>
      isVietnamese ? 'Giảng viên nổi bật' : 'Featured tutors';
  String get seeMore => isVietnamese ? 'Xem thêm' : 'See more';
  String get seeAll => isVietnamese ? 'Xem tất cả' : 'See all';
  String get searchUsersOrClassCode => isVietnamese
      ? 'Tìm người dùng hoặc nhập mã lớp'
      : 'Search users or enter a class code';
  String get noUpcomingClasses => isVietnamese
      ? 'Chưa có lớp học sắp diễn ra.'
      : 'No upcoming classes yet.';
  String get upcomingTeachingClasses =>
      isVietnamese ? 'Lớp học sắp dạy' : 'Upcoming teaching classes';
  String get noTeachingClasses =>
      isVietnamese ? 'Chưa có lớp học nào sắp dạy' : 'No teaching classes yet';
  String get createClassNow =>
      isVietnamese ? 'Tạo buổi học ngay' : 'Create a class';

  String loadDataError(String message) {
    return isVietnamese
        ? 'Không thể tải dữ liệu: $message'
        : 'Could not load data: $message';
  }

  String todayClassCount(int count) {
    if (isVietnamese) {
      return count == 1
          ? 'Hôm nay bạn có 1 lớp học'
          : 'Hôm nay bạn có $count lớp học';
    }
    return count == 1
        ? 'You have 1 class today'
        : 'You have $count classes today';
  }

  String seeMoreClasses(int count) {
    return isVietnamese
        ? 'Xem thêm $count lớp khác'
        : 'See $count more classes';
  }

  String classCount(int count) {
    if (isVietnamese) return '$count lớp';
    return count == 1 ? '1 class' : '$count classes';
  }

  String sessionCount(int count) {
    if (isVietnamese) return '$count buổi';
    return count == 1 ? '1 session' : '$count sessions';
  }

  String classStatusLabel(String status) {
    final normalized = status.trim().toUpperCase();
    return switch (normalized) {
      'OPEN' || 'SCHEDULED' => text(en: 'Open', vi: 'Đang mở'),
      'LIVE' || 'ONGOING' => text(en: 'Live', vi: 'Đang diễn ra'),
      'DONE' || 'COMPLETED' => text(en: 'Completed', vi: 'Hoàn thành'),
      'HUỶ' ||
      'HỦY' ||
      'HUY' ||
      'CANCELLED' ||
      'CANCELED' => text(en: 'Cancelled', vi: 'Hủy'),
      _ => status,
    };
  }

  String classTimeText(String value) {
    return value
        .replaceAll('Hôm nay', text(en: 'Today', vi: 'Hôm nay'))
        .replaceAll('Ngày mai', text(en: 'Tomorrow', vi: 'Ngày mai'));
  }

  String? classDateText(String? value) {
    final textValue = value?.trim();
    if (textValue == null || textValue.isEmpty) {
      return value;
    }
    return classTimeText(textValue);
  }

  String? classCountdownText(String? value) {
    final textValue = value?.trim();
    if (textValue == null || textValue.isEmpty) {
      return value;
    }
    if (textValue == 'Hết chỗ') {
      return text(en: 'Full', vi: 'Hết chỗ');
    }
    final match = RegExp(r'^Còn\s+(\d+)\s+chỗ$').firstMatch(textValue);
    if (match != null) {
      final remaining = int.tryParse(match.group(1) ?? '') ?? 0;
      if (isVietnamese) return 'Còn $remaining chỗ';
      return remaining == 1 ? '1 slot left' : '$remaining slots left';
    }
    return textValue;
  }

  String? classSlotText(String? value) {
    final textValue = value?.trim();
    if (textValue == null || textValue.isEmpty) {
      return value;
    }
    final match = RegExp(r'^(\d+)\/(\d+)\s+đã đăng ký$').firstMatch(textValue);
    if (match != null) {
      final current = match.group(1) ?? '0';
      final max = match.group(2) ?? '0';
      return isVietnamese ? '$current/$max đã đăng ký' : '$current/$max joined';
    }
    return textValue;
  }

  String paymentCreationStatusLabel(String status) {
    return switch (status) {
      'unpaid' => text(en: 'Unpaid', vi: 'Chưa thanh toán'),
      'pending' => text(en: 'Pending payment', vi: 'Đang chờ thanh toán'),
      'paid' => text(en: 'Paid', vi: 'Đã thanh toán'),
      'refund_processing' => text(
        en: 'Refund processing',
        vi: 'Hoàn phí đang được xử lý',
      ),
      'refund_failed' => text(en: 'Refund failed', vi: 'Hoàn phí thất bại'),
      'refunded' => text(en: 'Refund recorded', vi: 'Đã ghi nhận hoàn phí'),
      _ => genericStatusLabel(status),
    };
  }

  String genericStatusLabel(String status) {
    return switch (status) {
      'scheduled' => text(en: 'Scheduled', vi: 'Đã lên lịch'),
      'ongoing' => text(en: 'Ongoing', vi: 'Đang diễn ra'),
      'completed' => text(en: 'Completed', vi: 'Hoàn thành'),
      'cancelled' || 'canceled' => text(en: 'Cancelled', vi: 'Đã hủy'),
      'pending' => text(en: 'Pending', vi: 'Đang chờ'),
      'confirmed' => text(en: 'Confirmed', vi: 'Đã xác nhận'),
      'not_confirmed' => text(en: 'Not confirmed', vi: 'Chưa xác nhận'),
      'paid' => text(en: 'Paid', vi: 'Đã thanh toán'),
      'released' => text(en: 'Released', vi: 'Đã đối soát'),
      'failed' => text(en: 'Failed', vi: 'Thất bại'),
      'refunded' => text(en: 'Refunded', vi: 'Đã hoàn tiền'),
      '' => '--',
      _ => status,
    };
  }

  List<String> get weekdayShortLabels => isVietnamese
      ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  List<String> get weekdayFullLabels => isVietnamese
      ? const [
          'Thứ hai',
          'Thứ ba',
          'Thứ tư',
          'Thứ năm',
          'Thứ sáu',
          'Thứ bảy',
          'Chủ nhật',
        ]
      : const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];

  List<String> get monthLabels => isVietnamese
      ? const [
          'tháng 1',
          'tháng 2',
          'tháng 3',
          'tháng 4',
          'tháng 5',
          'tháng 6',
          'tháng 7',
          'tháng 8',
          'tháng 9',
          'tháng 10',
          'tháng 11',
          'tháng 12',
        ]
      : const [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];

  String selectedDateLabel(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final weekday = weekdayFullLabels[date.weekday - 1];
    final month = monthLabels[date.month - 1];
    if (isVietnamese) {
      return '$weekday, ${date.day} $month';
    }
    return '$weekday, $month ${date.day}';
  }
}
