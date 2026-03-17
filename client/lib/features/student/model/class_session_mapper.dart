import 'package:client/features/student/model/class_session.dart';

class ClassSessionMapper {
  static ClassSession fromMap(Map<String, dynamic> m) {
    final startTime = DateTime.parse(m['start_time']).toLocal();
    final maxSlots = (m['max_participants'] as num).toInt();
    final current = (m['current_participants'] as num).toInt();
    final remaining = maxSlots - current;
    final topic = m['topic'] as Map<String, dynamic>;
    final teacher = m['teacher'] as Map<String, dynamic>;

    return ClassSession(
      id: m['id'] as String,
      classCode: m['class_code'] as String?,
      title: m['title'] as String,
      location: m['location_name'] as String,
      teacherId: teacher['id'] as String?,
      teacherName: teacher['full_name'] as String,
      teacherAvatarUrl: teacher['avatar_url'] as String?,
      startDateTime: startTime,
      timeText: formatTime(startTime),
      priceText: formatPrice(m['price']),
      imageUrl: m['thumbnail_url'] as String?,
      statusText: mapStatus(m['status'] as String),
      countdownText: remaining > 0 ? 'Còn $remaining chỗ' : 'Hết chỗ',
      tags: [topic['name'] as String],
      description: m['description'] as String?,
      dateText: formatDate(startTime),
      slotText: '$current/$maxSlots đã đăng ký',
      levelText: mapLevel(m['level'] as String),
      teacherRating: teacher['rating_avg'] != null
          ? double.tryParse(teacher['rating_avg'].toString())
          : null,
      teacherSessionCount: teacher['total_sessions'] as int?,
    );
  }

  static String formatTime(DateTime dt) {
    final diff = _dayDiff(dt);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (diff == 0) return '$hh:$mm Hôm nay';
    if (diff == 1) return '$hh:$mm Ngày mai';
    return '$hh:$mm ${dt.day}/${dt.month}';
  }

  static String formatDate(DateTime dt) {
    final diff = _dayDiff(dt);
    final dayMonth =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Hôm nay, $dayMonth';
    if (diff == 1) return 'Ngày mai, $dayMonth';
    return dayMonth;
  }

  static String formatPrice(dynamic price) {
    final str = double.parse(price.toString()).toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return '${buf.toString()}đ';
  }

  static String mapStatus(String status) => switch (status) {
        'scheduled' => 'OPEN',
        'ongoing'   => 'LIVE',
        'completed' => 'DONE',
        'cancelled' => 'HUỶ',
        _           => status.toUpperCase(),
      };

  static String mapLevel(String level) => switch (level) {
        'beginner'     => 'Beginner',
        'intermediate' => 'Intermediate+',
        'advanced'     => 'Advanced',
        _              => level,
      };

  static int _dayDiff(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final classDay = DateTime(dt.year, dt.month, dt.day);
    return classDay.difference(today).inDays;
  }
}
