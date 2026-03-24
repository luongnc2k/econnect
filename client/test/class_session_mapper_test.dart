import 'package:client/features/student/model/class_session_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'class session mapper rewrites backend-hosted static thumbnail to current server origin',
    () {
      final session = ClassSessionMapper.fromMap({
        'id': 'class-1',
        'class_code': 'CLS-260323-ABCD',
        'title': 'Mock class',
        'description': 'Description',
        'level': 'beginner',
        'location_name': 'Cafe A',
        'location_address': '123 Main Street',
        'location_notes': 'Vào cổng phụ tầng 2.',
        'start_time': '2026-03-24T10:00:00Z',
        'end_time': '2026-03-24T12:00:00Z',
        'min_participants': 1,
        'max_participants': 4,
        'current_participants': 1,
        'price': '120000',
        'thumbnail_url':
            'https://demo.ngrok-free.app/static/class-thumbnails/example.jpeg',
        'status': 'scheduled',
        'topic': 'Business English',
        'teacher': {
          'id': 'teacher-1',
          'full_name': 'Tutor Demo',
          'avatar_url': null,
          'rating_avg': null,
          'total_sessions': null,
        },
      });

      expect(
        session.imageUrl,
        'http://10.0.2.2:8000/static/class-thumbnails/example.jpeg',
      );
      expect(session.location, 'Cafe A');
      expect(session.locationAddress, '123 Main Street');
      expect(session.locationNotes, 'Vào cổng phụ tầng 2.');
      expect(session.priceText, '30.000đ');
      expect(session.totalPriceText, '120.000đ');
    },
  );
}
