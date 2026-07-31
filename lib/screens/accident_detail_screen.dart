import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../models/accident_record.dart';
import '../services/accident_service.dart';
import '../services/ai_analysis_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'accident_form_screen.dart';

class AccidentDetailScreen extends StatefulWidget {
  final AccidentRecord record;
  const AccidentDetailScreen({super.key, required this.record});

  @override
  State<AccidentDetailScreen> createState() => _AccidentDetailScreenState();
}

class _AccidentDetailScreenState extends State<AccidentDetailScreen> {
  late AccidentRecord _record;
  bool _isGenerating = false;
  final _aiService = AiAnalysisService();

  final _why1Ctrl = TextEditingController();
  final _why2Ctrl = TextEditingController();
  final _why3Ctrl = TextEditingController();
  final _why4Ctrl = TextEditingController();
  final _rootCauseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _syncControllers();
  }

  void _syncControllers() {
    _why1Ctrl.text = _record.causeAnalysis.why1;
    _why2Ctrl.text = _record.causeAnalysis.why2;
    _why3Ctrl.text = _record.causeAnalysis.why3;
    _why4Ctrl.text = _record.causeAnalysis.why4;
    _rootCauseCtrl.text = _record.causeAnalysis.rootCause;
  }

  @override
  void dispose() {
    _why1Ctrl.dispose();
    _why2Ctrl.dispose();
    _why3Ctrl.dispose();
    _why4Ctrl.dispose();
    _rootCauseCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAiDraft() async {
    final settings = context.read<SettingsService>();
    if (!settings.hasApiKey) {
      _showApiKeyMissingDialog();
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final result = await _aiService.generateCauseAnalysis(
        apiKey: settings.geminiApiKey,
        record: _record,
      );
      setState(() {
        _why1Ctrl.text = result.why1;
        _why2Ctrl.text = result.why2;
        _why3Ctrl.text = result.why3;
        _why4Ctrl.text = result.why4;
        _rootCauseCtrl.text = result.rootCause;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AIによる分析ドラフトを生成しました。内容を確認・編集して保存してください。'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showApiKeyMissingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini APIキー未設定'),
        content: const Text('AI分析機能を使用するには、設定画面でGemini APIキーを登録してください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAnalysis({required bool editedManually}) async {
    final updated = _record.copyWith(
      causeAnalysis: _record.causeAnalysis.copyWith(
        why1: _why1Ctrl.text,
        why2: _why2Ctrl.text,
        why3: _why3Ctrl.text,
        why4: _why4Ctrl.text,
        rootCause: _rootCauseCtrl.text,
        isAiDraft: !editedManually && _record.causeAnalysis.isAiDraft,
        editedBy: context.read<SettingsService>().userName,
      ),
      status: RecordStatus.analyzed,
    );
    await context.read<AccidentService>().updateRecord(updated);
    setState(() => _record = updated);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('原因分析を保存しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final dateStr = DateFormat(
      'yyyy年MM月dd日(E) HH:mm',
      'ja_JP',
    ).format(r.occurredAt);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: const Text('事故詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final updated = await Navigator.push<AccidentRecord>(
                context,
                MaterialPageRoute(
                  builder: (_) => AccidentFormScreen(existing: r),
                ),
              );
              if (updated != null) setState(() => _record = updated);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(r, dateStr),
              const SizedBox(height: 16),
              _buildInfoSection(r),
              const SizedBox(height: 16),
              _buildCauseAnalysisSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AccidentRecord r, String dateStr) {
    final typeColor = AppColors.forAccidentType(r.accidentType);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  r.accidentType.label,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.forStatus(r.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  r.status.label,
                  style: TextStyle(
                    color: AppColors.forStatus(r.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dateStr,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r.location.isEmpty ? '(場所未記入)' : r.location,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            r.description,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(AccidentRecord r) {
    final rows = <(String, String)>[
      ('発生部署', r.office.label),
      if (r.partsCause != null) ('発生要因', r.partsCause!.label),
      ('氏名', r.driverName.isEmpty ? '-' : r.driverName),
      ('社員番号', r.employeeNumber.isEmpty ? '-' : r.employeeNumber),
      ('年齢', r.age != null ? '${r.age}歳' : '-'),
      (
        '勤続年数',
        r.yearsOfServiceYear != null
            ? '${r.yearsOfServiceYear}年${r.yearsOfServiceMonth ?? 0}ヶ月'
            : '-',
      ),
      (
        '業務経験年数',
        r.yearsOfExperienceYear != null
            ? '${r.yearsOfExperienceYear}年${r.yearsOfExperienceMonth ?? 0}ヶ月'
            : '-',
      ),
      ('相手方/荷主', r.counterparty.isEmpty ? '-' : r.counterparty),
      ('保険有無', r.insurance.label),
      ('金額', r.amount == 0 ? '-' : '¥${_formatNumber(r.amount)}'),
      (
        '賠償金額',
        r.compensationAmount == 0
            ? '-'
            : '¥${_formatNumber(r.compensationAmount)}',
      ),
      (
        '事故処理諸費用',
        r.processingCost == 0 ? '-' : '¥${_formatNumber(r.processingCost)}',
      ),
      ('ランク', r.rank.isEmpty ? '-' : r.rank),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '詳細情報',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              for (final row in rows)
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(double v) => NumberFormat('#,###').format(v);

  Widget _buildCauseAnalysisSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '原因分析（なぜなぜ分析）',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAiDraft,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_isGenerating ? '生成中...' : 'AIでドラフト生成'),
              ),
            ],
          ),
          if (_record.causeAnalysis.isAiDraft)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '※AI生成のドラフトです。内容を確認・修正のうえ保存してください。',
                style: TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ),
          const SizedBox(height: 14),
          _whyField('Why① なぜ発生したか', _why1Ctrl),
          _whyField('Why② why①に対してなぜ', _why2Ctrl),
          _whyField('Why③ why②に対してなぜ', _why3Ctrl),
          _whyField('Why④ why③に対してなぜ', _why4Ctrl),
          const SizedBox(height: 8),
          const Text(
            '真因（最終結論）',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _rootCauseCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '真因を入力...'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _saveAnalysis(editedManually: true),
              child: const Text('原因分析を保存'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _whyField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: 2,
            decoration: const InputDecoration(hintText: '入力...'),
          ),
        ],
      ),
    );
  }
}
