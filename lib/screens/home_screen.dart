import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/accident_service.dart';
import '../services/accident_target_service.dart';
import '../services/auth_service.dart';
import '../services/migration_service.dart';
import '../widgets/responsive_shell.dart';
import 'dashboard_screen.dart';
import 'accident_list_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'accident_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['ダッシュボード', '事故一覧', '傾向分析', '設定'];

  final _screens = const [
    DashboardScreen(),
    AccidentListScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final accidentService = context.read<AccidentService>();
      final targetService = context.read<AccidentTargetService>();
      await accidentService.loadRecords();
      if (accidentService.records.isEmpty) {
        await MigrationService().runIfNeeded(accidentService);
      }
      await targetService.loadTargets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthService>().canEdit;
    return ResponsiveShell(
      currentIndex: _index,
      onTap: (i) => setState(() => _index = i),
      title: _titles[_index],
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: (canEdit && (_index == 0 || _index == 1))
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccidentFormScreen()),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
