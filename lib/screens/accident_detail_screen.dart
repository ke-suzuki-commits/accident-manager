import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../models/accident_record.dart';
import '../models/app_user.dart';
import '../models/edit_log.dart';
import '../services/accident_service.dart';
import '../services/ai_analysis_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/kana_normalize.dart';
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

  // 事故後対応の実績（課長面談・班ミーティング）用の編集中の状態。
  DateTime? _interviewDate;
  String _interviewerName = '';
  DateTime? _meetingDate;
  bool _isSavingFollowUp = false;

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
    _interviewDate = _record.followUp.interviewDate;
    _interviewerName = _record.followUp.interviewerName;
    _meetingDate = _record.followUp.meetingDate;
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

  Future<void> _pickInterviewDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _interviewDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _interviewDate = picked);
  }

  Future<void> _pickMeetingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _meetingDate = picked);
  }

  /// 事故後対応の実績（課長面談・班ミーティング）を保存する。
  /// ※ 本項目はユーザー指示により編集履歴(edit_logs)には記録しない。
  /// (updateRecordの差分検出は対象フィールドをホワイトリスト管理しており、
  ///  followUpの変更のみでは差分が検出されないため、自動的にログ対象外となる)
  Future<void> _saveFollowUp() async {
    final auth = context.read<AuthService>();
    setState(() => _isSavingFollowUp = true);
    try {
      final updated = _record.copyWith(
        followUp: _record.followUp.copyWith(
          interviewDate: _interviewDate,
          clearInterviewDate: _interviewDate == null,
          interviewerName: _interviewerName,
          meetingDate: _meetingDate,
          clearMeetingDate: _meetingDate == null,
        ),
      );
      await context.read<AccidentService>().updateRecord(
        updated,
        editorUid: auth.firebaseUser?.uid ?? '',
        editorName: auth.currentUser?.name ?? '',
        editorEmail: auth.currentUser?.email ?? '',
      );
      setState(() => _record = updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('事故後対応の実績を保存しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingFollowUp = false);
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
    final auth = context.read<AuthService>();
    // 記録者名は、認証ユーザーの氏名を優先し、未取得の場合のみ
    // 設定画面の手入力名(userName)にフォールバックする。
    final editorName =
        auth.currentUser?.name ?? context.read<SettingsService>().userName;
    final updated = _record.copyWith(
      causeAnalysis: _record.causeAnalysis.copyWith(
        // 半角カタカナの濁点/半濁点による文字化けを防ぐため正規化する。
        why1: normalizeHalfWidthKana(_why1Ctrl.text),
        why2: normalizeHalfWidthKana(_why2Ctrl.text),
        why3: normalizeHalfWidthKana(_why3Ctrl.text),
        why4: normalizeHalfWidthKana(_why4Ctrl.text),
        rootCause: normalizeHalfWidthKana(_rootCauseCtrl.text),
        isAiDraft: !editedManually && _record.causeAnalysis.isAiDraft,
        editedBy: editorName,
      ),
      status: RecordStatus.analyzed,
    );
    await context.read<AccidentService>().updateRecord(
      updated,
      editorUid: auth.firebaseUser?.uid ?? '',
      editorName: editorName,
      editorEmail: auth.currentUser?.email ?? '',
    );
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
    final canEdit = context.watch<AuthService>().canEdit;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: const Text('事故詳細'),
        actions: [
          if (canEdit)
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
              _buildCauseAnalysisSection(canEdit),
              const SizedBox(height: 16),
              _buildFollowUpSection(canEdit),
              const SizedBox(height: 16),
              _buildEditHistorySection(r),
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
      ('発生区分（庸車/自社）', r.office.isCharter ? '庸車事故' : '自社事故'),
      ('班', r.team.label),
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

  Widget _buildCauseAnalysisSection(bool canEdit) {
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
              if (canEdit)
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
          if (!canEdit)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '※閲覧権限のため編集できません。',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
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
          _whyField('Why① なぜ発生したか', _why1Ctrl, canEdit),
          _whyField('Why② why①に対してなぜ', _why2Ctrl, canEdit),
          _whyField('Why③ why②に対してなぜ', _why3Ctrl, canEdit),
          _whyField('Why④ why③に対してなぜ', _why4Ctrl, canEdit),
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
            // スマホ等の狭い画面では同じ文章でも折り返し行数が増えるため、
            // 固定行数だと文字が見切れる。minLines/maxLinesをnullにし、
            // 内容量に応じて入力欄の高さが自動的に伸びるようにする。
            minLines: 3,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            enabled: canEdit,
            decoration: const InputDecoration(hintText: '真因を入力...'),
          ),
          const SizedBox(height: 16),
          if (canEdit)
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

  Widget _buildFollowUpSection(bool canEdit) {
    final dateFmt = DateFormat('yyyy年MM月dd日');
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
            '事故後対応の実績',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '担当課長による面談、および所属班でのミーティングの実施記録です。（任意項目）',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          if (!canEdit)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '※閲覧権限のため編集できません。',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            '課長面談',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: InkWell(
                  onTap: canEdit ? _pickInterviewDate : null,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '面談実施日'),
                    child: Text(
                      _interviewDate != null
                          ? dateFmt.format(_interviewDate!)
                          : '未実施',
                      style: TextStyle(
                        color: _interviewDate != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 260, child: _interviewerSelector(canEdit)),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '班ミーティング',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 220,
            child: InkWell(
              onTap: canEdit ? _pickMeetingDate : null,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'ミーティング実施日'),
                child: Text(
                  _meetingDate != null ? dateFmt.format(_meetingDate!) : '未実施',
                  style: TextStyle(
                    color: _meetingDate != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (canEdit)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingFollowUp ? null : _saveFollowUp,
                child: _isSavingFollowUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('事故後対応の実績を保存'),
              ),
            ),
        ],
      ),
    );
  }

  /// 面談担当者の選択欄。
  /// 「課長職」に該当する社員マスタが別途無いため、社員アカウント管理に
  /// 登録済みの編集者・管理者権限の社員を対象に選択させる(閲覧者は除外)。
  Widget _interviewerSelector(bool canEdit) {
    if (!canEdit) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: '面談担当者'),
        child: Text(
          _interviewerName.isEmpty ? '未選択' : _interviewerName,
          style: TextStyle(
            color: _interviewerName.isEmpty
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
        ),
      );
    }
    return StreamBuilder<List<AppUser>>(
      stream: context.read<AuthService>().watchUsers(),
      builder: (context, snapshot) {
        final candidates = (snapshot.data ?? [])
            .where((u) => u.role.canEdit)
            .toList();
        // 保存済みの担当者名が候補一覧に無い場合(退職・権限変更等)でも
        // 選択値が消えてしまわないよう、ドロップダウンの選択肢に補完しておく。
        final names = candidates.map((u) => u.name).toSet();
        if (_interviewerName.isNotEmpty && !names.contains(_interviewerName)) {
          names.add(_interviewerName);
        }
        return DropdownButtonFormField<String>(
          initialValue: _interviewerName.isEmpty ? null : _interviewerName,
          decoration: const InputDecoration(labelText: '面談担当者'),
          hint: const Text('選択してください'),
          isExpanded: true,
          items: [
            for (final name in names)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (value) =>
              setState(() => _interviewerName = value ?? ''),
        );
      },
    );
  }

  Widget _buildEditHistorySection(AccidentRecord r) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                '編集履歴（証跡）',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<EditLog>>(
            future: context.read<AccidentService>().getEditLogs(r.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Text(
                  '編集履歴はありません。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final log in logs) _editLogTile(log)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _editLogTile(EditLog log) {
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(log.timestamp);
    Color badgeColor;
    switch (log.action) {
      case EditAction.create:
        badgeColor = AppColors.success;
        break;
      case EditAction.update:
        badgeColor = AppColors.secondary;
        break;
      case EditAction.delete:
        badgeColor = AppColors.danger;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  log.action.label,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${log.editorName}（${log.editorEmail}）',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (log.changes.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final c in log.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${c.fieldLabel}: ',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: c.oldValue,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const TextSpan(text: '  →  '),
                      TextSpan(
                        text: c.newValue,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _whyField(String label, TextEditingController ctrl, bool canEdit) {
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
            // スマホ等の狭い画面では同じ文章でも折り返し行数が増えるため、
            // 固定行数だと文字が見切れる。minLines/maxLinesをnullにし、
            // 内容量に応じて入力欄の高さが自動的に伸びるようにする。
            minLines: 2,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            enabled: canEdit,
            decoration: const InputDecoration(hintText: '入力...'),
          ),
        ],
      ),
    );
  }
}
