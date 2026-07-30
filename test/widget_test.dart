// 事故履歴管理アプリ 基本起動テスト

import 'package:flutter_test/flutter_test.dart';

import 'package:accident_manager/main.dart';
import 'package:accident_manager/services/settings_service.dart';

void main() {
  testWidgets('App boots and shows dashboard title', (
    WidgetTester tester,
  ) async {
    final settingsService = SettingsService();
    await settingsService.load();

    await tester.pumpWidget(MyApp(settingsService: settingsService));
    await tester.pumpAndSettle();

    expect(find.text('ダッシュボード'), findsWidgets);
  });
}
