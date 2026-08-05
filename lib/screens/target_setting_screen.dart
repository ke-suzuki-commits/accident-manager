import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/accident_master.dart';
import '../models/accident_record.dart';
import '../services/accident_service.dart';
import '../services/accident_target_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// 年度事故件数目標(全社・班別)の設定画面。管理者のみアクセス可能。
class TargetSettingScreen extends StatefulWidget {
  const TargetSettingScreen({super.key});

  @override
  State<TargetSettingScreen> createState() => _TargetSettingScreenState();
}

class _TargetSettingScreenState extends State<TargetSettingScreen> {
  late final int _currentFiscalYear;
  late int _fiscalYear;
  final _companyCtrl = TextEditingController();
  final Map<Team, TextEditingController> _teamCtrls = {
    for (final t in Team.values)
      if (t != Team.unassigned) t: TextEditingController(),
  };
  bool _isSaving = false;

  // 役員指示によるデフォルト目標値(今年度・未設定の場合のみ表示上プリフィルする)。
  // 実際にFirestoreへ保存されるのは「保存する」ボタンを押した時点。
  static const int _defaultCompanyTarget = 54; // 自社事故のみ(庸車除く)
  static const Map<Team, int> _defaultTeamTargets = {
    Team.n: 2,
    Team.m: 2,
    Team.o: 2,
  };

  @override
  void initState() {
    super.initState();
    _currentFiscalYear = AccidentRecord.calcFiscalYear(DateTime.now());
    _fiscalYear = _currentFiscalYear;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadValues());
  }

  void _loadValues() {
    final targetService = context.read<AccidentTargetService>();
    final isCurrentYear = _fiscalYear == _currentFiscalYear;
    final company = targetService.companyTarget(_fiscalYear);
    if (company != null) {
      _companyCtrl.text = company.targetCount != 0
          ? company.targetCount.toString()
          : '';
    } else {
      // 未設定(今年度)の場合のみ、役員指示のデフォルト値をプリフィルする。
      _companyCtrl.text = isCurrentYear ? _defaultCompanyTarget.toString() : '';
    }
    for (final t in _teamCtrls.keys) {
      final target = targetService.teamTarget(_fiscalYear, t);
      if (target != null) {
        _teamCtrls[t]!.text = target.targetCount != 0
            ? target.targetCount.toString()
            : '';
      } else {
        final defaultVal = _defaultTeamTargets[t];
        _teamCtrls[t]!.text = (isCurrentYear && defaultVal != null)
            ? defaultVal.toString()
            : '';
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    for (final c in _teamCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final targetService = context.read<AccidentTargetService>();
    final auth = context.read<AuthService>();
    final updatedBy = auth.currentUser?.name ?? '不明';
    try {
      final companyCount = int.tryParse(_companyCtrl.text) ?? 0;
      await targetService.setCompanyTarget(
        fiscalYear: _fiscalYear,
        targetCount: companyCount,
        updatedBy: updatedBy,
      );
      for (final entry in _teamCtrls.entries) {
        final count = int.tryParse(entry.value.text) ?? 0;
        await targetService.setTeamTarget(
          fiscalYear: _fiscalYear,
          team: entry.key,
          targetCount: count,
          updatedBy: updatedBy,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$_fiscalYear年度の目標を保存しました')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accidentService = context.watch<AccidentService>();
    // 全社目標(例:54件)は「自社事故のみ」が基準(庸車事故は含まない)。
    // 庸車事故は目標の対象外のため、参考件数として別途表示する。
    final currentCompanyCount = accidentService.ownCompanyAccidentCount(
      _fiscalYear,
    );
    final charterCount = accidentService.charterAccidentCount(_fiscalYear);
    final excludedCount = accidentService.excludedCount(_fiscalYear);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: const Text('年度事故目標の設定'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _yearSelector(),
              const SizedBox(height: 16),
              _card(
                title: '全社目標',
                children: [
                  Text(
                    '現在の累計件数(自社事故のみ): $currentCompanyCount件',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '（庸車事故 $charterCount件は目標の対象外・参考件数）',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  if (excludedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '（無責・責任区分不明 $excludedCount件は集計対象外）',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _companyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '$_fiscalYear年度 目標件数(全社・自社事故のみ)',
                      suffixText: '件',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _card(
                title: '班別目標',
                children: [
                  const Text(
                    '未設定のままにすると、その班は目標なしとして扱われます。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_fiscalYear == _currentFiscalYear)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'N班・M班・O班は目標件数2件が初期入力されています。'
                        '内容を確認し「保存する」を押してください。',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  ...(_teamCtrls.entries.map((entry) {
                    final team = entry.key;
                    final count = accidentService
                        .countableByFiscalYear(_fiscalYear)
                        .where((r) => r.team == team)
                        .length;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              team.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: entry.value,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '目標件数(現在$count件)',
                                suffixText: '件',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('保存する'),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yearSelector() {
    final years = <int>{
      AccidentRecord.calcFiscalYear(DateTime.now()) + 1,
      AccidentRecord.calcFiscalYear(DateTime.now()),
      AccidentRecord.calcFiscalYear(DateTime.now()) - 1,
    }.toList()..sort((a, b) => b.compareTo(a));
    return Row(
      children: [
        const Text('対象年度:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: _fiscalYear,
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text('$y年度')))
              .toList(),
          onChanged: (y) {
            if (y == null) return;
            setState(() => _fiscalYear = y);
            _loadValues();
          },
        ),
      ],
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
