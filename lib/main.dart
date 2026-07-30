import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'repositories/accident_repository.dart';
import 'services/accident_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting('ja_JP');

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
          create: (_) => AccidentService(HiveAccidentRepository()),
        ),
        ChangeNotifierProvider.value(value: settingsService),
      ],
      child: MaterialApp(
        title: '事故履歴管理',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        locale: const Locale('ja', 'JP'),
        supportedLocales: const [Locale('ja', 'JP')],
        home: const HomeScreen(),
      ),
    );
  }
}
