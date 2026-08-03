import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'repositories/accident_repository.dart';
import 'repositories/firestore_accident_repository.dart';
import 'services/accident_service.dart';
import 'services/accident_target_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

/// Firebase接続に成功したかどうか。
/// 成功時はFirestore(クラウド共有)、失敗時はHive(ローカル保存)を使う。
bool _firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // リリースモードでも予期せぬ描画エラーが起きた場合に原因が追跡できるよう、
  // コンソールへ簡潔なエラー概要を出力する(ユーザー画面には影響しない安全な計装)。
  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  await Hive.initFlutter();
  await initializeDateFormatting('ja_JP');

  // Firebase初期化(Web/Androidそれぞれの設定をfirebase_options.dartから読込)
  // 本社・三島営業所間でデータを共有するにはFirestore接続が必須。
  // 万一オフライン等で初期化に失敗した場合は、業務が止まらないよう
  // ローカル(Hive)保存に自動フォールバックする。
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
  } catch (e) {
    _firebaseReady = false;
    // リリースビルドでも原因追跡できるよう常時出力する
    // (kDebugModeガードを外すと、Firebase接続失敗時にHiveへ
    //  無言でフォールバックし気づけなくなるため)
    debugPrint('Firebase初期化に失敗しました(ローカル保存で継続します): $e');
  }

  final settingsService = SettingsService();
  await settingsService.load();

  runApp(MyApp(settingsService: settingsService));
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;
  const MyApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AccidentService(
            _firebaseReady
                ? FirestoreAccidentRepository()
                : HiveAccidentRepository(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AccidentTargetService()),
        ChangeNotifierProvider.value(value: settingsService),
      ],
      child: MaterialApp(
        title: '事故履歴管理',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        locale: const Locale('ja', 'JP'),
        supportedLocales: const [Locale('ja', 'JP')],
        // RefreshIndicator / TextField など多数のMaterialウィジェットが
        // 内部でMaterialLocalizationsを参照するため、デリゲートを明示的に登録する。
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AuthGate(),
      ),
    );
  }
}
