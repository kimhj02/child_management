// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:child_management/main.dart';

class _FakeLocalDataStore extends LocalDataStore {
  _FakeLocalDataStore({LocalDataPayload? payload})
      : _payload = payload ?? LocalDataPayload.empty();

  final LocalDataPayload _payload;

  @override
  Future<LocalDataPayload> load() async => _payload;

  @override
  Future<void> save({
    required List<Student> students,
    required List<StoreItem> storeItems,
  }) async {}
}

void main() {
  testWidgets('앱이 기본 화면을 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      StudentShopApp(
        dataStore: _FakeLocalDataStore(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('학생 상점 관리자'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('학생 관리'), findsOneWidget);
    expect(find.text('상점 룰렛'), findsOneWidget);
  });
}
