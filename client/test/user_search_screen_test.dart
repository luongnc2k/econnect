import 'dart:async';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/search/repositories/user_search_repository.dart';
import 'package:client/features/search/view/screens/user_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('user search screen builds with material scaffold', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp());

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Tìm kiếm'), findsOneWidget);
    expect(find.text('Tìm người dùng hoặc nhập mã lớp'), findsOneWidget);
  });

  testWidgets('user search debounces typing before calling repository', (
    tester,
  ) async {
    final fakeRepo = _FakeUserSearchRepository(
      immediateResults: {
        'alice': [_searchResult(fullName: 'Alice Final')],
      },
    );

    await tester.pumpWidget(_buildApp(fakeRepo: fakeRepo));

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'al');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'alice');
    await tester.pump(const Duration(milliseconds: 349));

    expect(fakeRepo.queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(fakeRepo.queries, ['alice']);
    expect(find.text('Alice Final'), findsOneWidget);
  });

  testWidgets('user search ignores stale results from older requests', (
    tester,
  ) async {
    final firstResult = Completer<List<UserModel>>();
    final secondResult = Completer<List<UserModel>>();
    final fakeRepo = _FakeUserSearchRepository(
      pendingResults: {'first': firstResult, 'second': secondResult},
    );

    await tester.pumpWidget(_buildApp(fakeRepo: fakeRepo));

    await tester.enterText(find.byType(TextField), 'first');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(fakeRepo.queries, ['first']);

    await tester.enterText(find.byType(TextField), 'second');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(fakeRepo.queries, ['first', 'second']);

    secondResult.complete([_searchResult(fullName: 'Second Result')]);
    await tester.pump();

    expect(find.text('Second Result'), findsOneWidget);

    firstResult.complete([_searchResult(fullName: 'First Result')]);
    await tester.pump();

    expect(find.text('Second Result'), findsOneWidget);
    expect(find.text('First Result'), findsNothing);
  });
}

Widget _buildApp({_FakeUserSearchRepository? fakeRepo}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_sampleCurrentUser()),
      if (fakeRepo != null)
        userSearchRepositoryProvider.overrideWithValue(fakeRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightThemeMode,
      home: const UserSearchScreen(),
    ),
  );
}

UserModel _sampleCurrentUser() {
  return UserModel(
    id: 'student-1',
    email: 'student@example.com',
    fullName: 'Student Demo',
    role: 'student',
    isActive: true,
    token: 'token-123',
  );
}

UserModel _searchResult({required String fullName}) {
  return UserModel(
    id: fullName.toLowerCase().replaceAll(' ', '-'),
    email: '${fullName.toLowerCase().replaceAll(' ', '.')}@example.com',
    fullName: fullName,
    role: 'teacher',
    isActive: true,
    token: 'token-123',
  );
}

class _FakeUserSearchRepository implements IUserSearchRepository {
  final Map<String, List<UserModel>> immediateResults;
  final Map<String, Completer<List<UserModel>>> pendingResults;
  final List<String> queries = [];

  _FakeUserSearchRepository({
    this.immediateResults = const {},
    this.pendingResults = const {},
  });

  @override
  Future<List<UserModel>> searchUsers(String query) {
    queries.add(query);
    final completer = pendingResults[query];
    if (completer != null) {
      return completer.future;
    }
    return Future.value(immediateResults[query] ?? const []);
  }
}
