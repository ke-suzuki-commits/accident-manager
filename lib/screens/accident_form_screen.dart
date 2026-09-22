import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../models/accident_record.dart';
import '../services/accident_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/kana_normalize.dart';
import '../utils/number_parse.dart';

class AccidentFormScreen extends StatefulWidget {
  final AccidentRecord? existing;
  const AccidentFormScreen({super.key, this.existing});

  @override
  State<AccidentFormScreen> createState() => _AccidentFormScreenState();
}

class _AccidentFormScreenState extends State<AccidentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late OfficeDept _office;
  late Team _team;
  late AccidentType _accidentType;
  late Responsibility _responsibility;
  PartsAccidentCause? _partsCause;
  late DateTime _occurredAt;
  late InsuranceStatus _insurance;

  final _locationCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _compensationCtrl = TextEditingController();
  final _processingCostCtrl = TextEditingController();

  // 発生者情報(複数名対応)。ドライバーに限らず事務員・倉庫作業者等も
  // 対象となり、また起因者が複数名の場合もあるため、リスト形式で
  // 入力欄を動的に追加・削除できるようにする。
  final List<_PersonFormData> _persons = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _office = e?.office ?? OfficeDept.first;
    _team = e?.team ?? Team.unassigned;
    _accidentType = e?.accidentType ?? AccidentType.property;
    _responsibility = e?.responsibility ?? Responsibility.atFault;
    _partsCause = e?.partsCause;
    _occurredAt = e?.occurredAt ?? DateTime.now();
    _insurance = e?.insurance ?? InsuranceStatus.unknown;

    _locationCtrl.text = e?.location ?? '';
    if (e != null && e.involvedPersons.isNotEmpty) {
      for (final p in e.involvedPersons) {
        _persons.add(_PersonFormData.fromPerson(p));
      }
    } else {
      // 新規登録時、または発生者が1名も登録されていない既存データの場合は
      // 最低1名分の入力欄を用意しておく(空欄のままでも保存は可能)。
      _persons.add(_PersonFormData());
    }
    _counterpartyCtrl.text = e?.counterparty ?? '';
    _descriptionCtrl.text = e?.description ?? '';
    _compensationCtrl.text = e != null && e.compensationAmount != 0
        ? e.compensationAmount.toStringAsFixed(0)
        : '';
    _processingCostCtrl.text = e != null && e.processingCost != 0
        ? e.processingCost.toStringAsFixed(0)
        : '';
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    for (final p in _persons) {
      p.dispose();
    }
    _counterpartyCtrl.dispose();
    _descriptionCtrl.dispose();
    _compensationCtrl.dispose();
    _processingCostCtrl.dispose();
    super.dispose();
  }

  void _addPerson() {
    setState(() => _persons.add(_PersonFormData()));
  }

  void _removePerson(int index) {
    setState(() {
      _persons[index].dispose();
      _persons.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (!mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final service = context.read<AccidentService>();
    final auth = context.read<AuthService>();
    final existing = widget.existing;
    final editorUid = auth.firebaseUser?.uid ?? '';
    final editorName = auth.currentUser?.name ?? '不明';
    final editorEmail = auth.currentUser?.email ?? '';

    // 事故No.の採番区分(自社(有責)/庸車(有責))を、発生部署・責任区分の
    // 入力内容から自動判定する。無責・責任区分不明はnull(採番対象外)。
    final category = numberingCategoryOf(
      office: _office,
      responsibility: _responsibility,
    );
    int? no;
    if (existing != null) {
      // 編集時: 採番区分が変わっていなければ既存のNo.を維持する。
      // 採番区分が変わった場合(例:責任区分を無責→有責に変更等)は、
      // 新しい区分内での連番を新規に振り直す。
      final existingCategory = existing.numberingCategory;
      if (existingCategory == category) {
        no = existing.no;
      } else if (category == null) {
        no = null; // 採番対象外に変わった
      } else {
        no = service.nextNoFor(category);
      }
    } else {
      no = category == null ? null : service.nextNoFor(category);
    }

    final record = AccidentRecord(
      id: existing?.id,
      no: no,
      office: _office,
      team: _team,
      accidentType: _accidentType,
      responsibility: _responsibility,
      partsCause: _accidentType == AccidentType.parts ? _partsCause : null,
      occurredAt: _occurredAt,
      // IME入力モードの誤りで半角カタカナが混在した場合の文字化け
      // (例: 「ｽｽﾞｷ」の濁点が豆腐表示になる)を防ぐため、保存時に
      // 全角カタカナへ正規化しておく。
      location: normalizeHalfWidthKana(_locationCtrl.text.trim()),
      // 発生者情報(複数名)。氏名・社員番号・年齢等が全て空の入力欄は
      // 保存対象から除外する(空の発生者が配列に紛れ込まないようにする)。
      involvedPersons: _persons
          .map((p) => p.toPerson())
          .where((p) => !p.isEmpty)
          .toList(),
      counterparty: normalizeHalfWidthKana(_counterpartyCtrl.text.trim()),
      description: normalizeHalfWidthKana(_descriptionCtrl.text.trim()),
      insurance: _insurance,
      // カンマ区切り(例:1,500,000)や全角数字での入力にも対応する
      // parseAmountOrNullを使用する。ここでnullになることは通常
      // 無いはずだが(下の_textFieldのvalidatorで事前に弾いているため)、
      // 万一のフォールバックとして0円扱いにする。
      compensationAmount: parseAmountOrNull(_compensationCtrl.text) ?? 0,
      processingCost: parseAmountOrNull(_processingCostCtrl.text) ?? 0,
      causeAnalysis: existing?.causeAnalysis,
      status: existing?.status ?? RecordStatus.reported,
      isMigrated: existing?.isMigrated ?? false,
      createdBy: existing?.createdBy ?? editorName,
    );

    if (_isEdit) {
      await service.updateRecord(
        record,
        editorUid: editorUid,
        editorName: editorName,
        editorEmail: editorEmail,
      );
    } else {
      await service.addRecord(
        record,
        editorUid: editorUid,
        editorName: editorName,
        editorEmail: editorEmail,
      );
    }

    if (mounted) Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: Text(_isEdit ? '事故記録の編集' : '事故記録の新規登録'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionCard('基本情報', [
                  _dateField(),
                  const SizedBox(height: 12),
                  _dropdownField<OfficeDept>(
                    label: '発生部署',
                    value: _office,
                    items: OfficeDept.values,
                    itemLabel: (e) => e.label,
                    onChanged: (v) => setState(() => _office = v!),
                  ),
                  const SizedBox(height: 12),
                  _dropdownField<Team>(
                    label: '班',
                    value: _team,
                    items: Team.values,
                    itemLabel: (e) => e.label,
                    onChanged: (v) => setState(() => _team = v!),
                  ),
                  const SizedBox(height: 12),
                  _dropdownField<AccidentType>(
                    label: '発生区分',
                    value: _accidentType,
                    items: AccidentType.values,
                    itemLabel: (e) => e.label,
                    onChanged: (v) => setState(() {
                      _accidentType = v!;
                      if (_accidentType != AccidentType.parts) {
                        _partsCause = null;
                      }
                    }),
                  ),
                  if (_accidentType == AccidentType.parts) ...[
                    const SizedBox(height: 12),
                    _dropdownField<PartsAccidentCause>(
                      label: '部品事故の発生要因',
                      value: _partsCause,
                      items: PartsAccidentCause.values,
                      itemLabel: (e) => e.label,
                      onChanged: (v) => setState(() => _partsCause = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _dropdownField<Responsibility>(
                    label: '責任区分',
                    value: _responsibility,
                    items: Responsibility.values,
                    itemLabel: (e) => e.label,
                    onChanged: (v) => setState(() => _responsibility = v!),
                  ),
                  if (_responsibility != Responsibility.atFault)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '※無責・責任区分不明の事故は、全体集計・班別集計の件数には'
                        '加算されません（一覧・詳細には表示されます）。',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _textField(_locationCtrl, '発生場所'),
                ]),
                const SizedBox(height: 16),
                _sectionCard('発生内容', [
                  _textField(
                    _descriptionCtrl,
                    '発生内容（詳細）',
                    maxLines: 4,
                    required: true,
                  ),
                ]),
                const SizedBox(height: 16),
                _buildInvolvedPersonsSection(),
                const SizedBox(height: 16),
                _sectionCard('金額・保険情報', [
                  _textField(
                    _compensationCtrl,
                    '賠償金額（支払金額）',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    isNumeric: true,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _processingCostCtrl,
                    '事故処理諸費用',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    isNumeric: true,
                  ),
                  const SizedBox(height: 12),
                  _dropdownField<InsuranceStatus>(
                    label: '保険有無',
                    value: _insurance,
                    items: InsuranceStatus.values,
                    itemLabel: (e) => e.label,
                    onChanged: (v) => setState(() => _insurance = v!),
                  ),
                  const SizedBox(height: 12),
                  _textField(_counterpartyCtrl, '相手方/荷主'),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_isEdit ? '更新する' : '登録する'),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 「発生者情報」セクション。
  /// ドライバーだけでなく事務員・倉庫作業者等も対象となるため中立的な
  /// 名称にしており、複数名(起因者が複数の場合)を動的に追加・削除できる。
  Widget _buildInvolvedPersonsSection() {
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '発生者情報',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addPerson,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('発生者を追加'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 12),
            child: Text(
              '事故の発生者(起因者)を入力してください。ドライバーに限らず、'
              '事務員・倉庫作業者等が発生させた場合も対象です。'
              '起因者が複数名の場合は「発生者を追加」で人数分入力できます。',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          for (var i = 0; i < _persons.length; i++)
            _personCard(index: i, data: _persons[i]),
        ],
      ),
    );
  }

  Widget _personCard({required int index, required _PersonFormData data}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '発生者${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.secondary,
                ),
              ),
              const Spacer(),
              if (_persons.length > 1)
                InkWell(
                  onTap: () => _removePerson(index),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _dropdownField<PersonRole>(
            label: '役職/立場',
            value: data.role,
            items: PersonRole.values,
            itemLabel: (e) => e.label,
            onChanged: (v) => setState(() => data.role = v!),
          ),
          const SizedBox(height: 12),
          _textField(data.nameCtrl, '氏名'),
          const SizedBox(height: 12),
          _textField(data.employeeNumberCtrl, '社員番号'),
          const SizedBox(height: 12),
          _textField(
            data.ageCtrl,
            '年齢',
            keyboardType: TextInputType.number,
            isNumeric: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _textField(
                  data.yearsOfServiceYearCtrl,
                  '勤続年数（年）',
                  keyboardType: TextInputType.number,
                  isNumeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  data.yearsOfServiceMonthCtrl,
                  '勤続年数（月）',
                  keyboardType: TextInputType.number,
                  isNumeric: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
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

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '発生日時'),
        child: Text(
          '${_occurredAt.year}/${_occurredAt.month.toString().padLeft(2, '0')}/${_occurredAt.day.toString().padLeft(2, '0')} '
          '${_occurredAt.hour.toString().padLeft(2, '0')}:${_occurredAt.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
    // 金額・年齢等の数値項目であることを示すフラグ。trueの場合、
    // カンマ区切りや全角数字であっても保存時に自動で解釈できるように
    // helperTextで書式の案内を出し、かつ数値として解釈できない入力を
    // 保存前にエラーとして弾く(黙って0円になる不具合の再発防止)。
    bool isNumeric = false,
  }) {
    // 複数行の入力欄(maxLines > 1、例: 発生内容の詳細)は、スマホ等の狭い画面だと
    // 同じ文章でも折り返し行数が増え、固定行数のままでは入力中の文字が見切れる。
    // そのためminLinesを基準行数、maxLinesを無制限にし、内容量に応じて
    // 入力欄の高さが自動的に伸びるようにする(単一行の項目は影響なし)。
    final isMultiline = maxLines > 1;
    return TextFormField(
      controller: ctrl,
      minLines: isMultiline ? maxLines : 1,
      maxLines: isMultiline ? null : 1,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        // カンマ区切り入力は自動で解釈されることをその場で案内し、
        // 誤入力(全角の単位混在等)にも気付きやすくする。
        helperText: isNumeric ? '例: 1500000 または 1,500,000' : null,
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) {
          return '$labelを入力してください';
        }
        if (isNumeric && v != null && v.trim().isNotEmpty) {
          if (parseAmountOrNull(v) == null) {
            return '$labelは数値で入力してください(例: 1500000)';
          }
        }
        return null;
      },
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// 発生者1名分の入力状態を保持するヘルパークラス。
/// UI側のTextEditingControllerと、保存用のPersonInvolvedモデルとの
/// 相互変換を担う。
class _PersonFormData {
  final TextEditingController nameCtrl;
  PersonRole role;
  final TextEditingController employeeNumberCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController yearsOfServiceYearCtrl;
  final TextEditingController yearsOfServiceMonthCtrl;

  _PersonFormData({
    String name = '',
    this.role = PersonRole.driver,
    String employeeNumber = '',
    String age = '',
    String yearsOfServiceYear = '',
    String yearsOfServiceMonth = '',
  }) : nameCtrl = TextEditingController(text: name),
       employeeNumberCtrl = TextEditingController(text: employeeNumber),
       ageCtrl = TextEditingController(text: age),
       yearsOfServiceYearCtrl = TextEditingController(text: yearsOfServiceYear),
       yearsOfServiceMonthCtrl = TextEditingController(
         text: yearsOfServiceMonth,
       );

  factory _PersonFormData.fromPerson(PersonInvolved p) {
    return _PersonFormData(
      name: p.name,
      role: p.role,
      employeeNumber: p.employeeNumber,
      age: p.age?.toString() ?? '',
      yearsOfServiceYear: p.yearsOfServiceYear?.toString() ?? '',
      yearsOfServiceMonth: p.yearsOfServiceMonth?.toString() ?? '',
    );
  }

  PersonInvolved toPerson() {
    return PersonInvolved(
      name: normalizeHalfWidthKana(nameCtrl.text.trim()),
      role: role,
      employeeNumber: employeeNumberCtrl.text.trim(),
      age: parseIntOrNull(ageCtrl.text),
      yearsOfServiceYear: parseIntOrNull(yearsOfServiceYearCtrl.text),
      yearsOfServiceMonth: parseIntOrNull(yearsOfServiceMonthCtrl.text),
      // 業務経験年数は現行フォームでは未入力項目のためnull固定。
      // (旧フォームにも入力欄が無かったため機能的な変更はない)
    );
  }

  void dispose() {
    nameCtrl.dispose();
    employeeNumberCtrl.dispose();
    ageCtrl.dispose();
    yearsOfServiceYearCtrl.dispose();
    yearsOfServiceMonthCtrl.dispose();
  }
}
