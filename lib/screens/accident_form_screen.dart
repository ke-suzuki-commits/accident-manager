import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../models/accident_record.dart';
import '../services/accident_service.dart';
import '../theme/app_theme.dart';

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
  PartsAccidentCause? _partsCause;
  late DateTime _occurredAt;
  late InsuranceStatus _insurance;

  final _locationCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _employeeNumberCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _yearsOfServiceYearCtrl = TextEditingController();
  final _yearsOfServiceMonthCtrl = TextEditingController();
  final _counterpartyCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _compensationCtrl = TextEditingController();
  final _processingCostCtrl = TextEditingController();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _office = e?.office ?? OfficeDept.first;
    _team = e?.team ?? Team.unassigned;
    _accidentType = e?.accidentType ?? AccidentType.property;
    _partsCause = e?.partsCause;
    _occurredAt = e?.occurredAt ?? DateTime.now();
    _insurance = e?.insurance ?? InsuranceStatus.unknown;

    _locationCtrl.text = e?.location ?? '';
    _driverNameCtrl.text = e?.driverName ?? '';
    _employeeNumberCtrl.text = e?.employeeNumber ?? '';
    _ageCtrl.text = e?.age?.toString() ?? '';
    _yearsOfServiceYearCtrl.text = e?.yearsOfServiceYear?.toString() ?? '';
    _yearsOfServiceMonthCtrl.text = e?.yearsOfServiceMonth?.toString() ?? '';
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
    _driverNameCtrl.dispose();
    _employeeNumberCtrl.dispose();
    _ageCtrl.dispose();
    _yearsOfServiceYearCtrl.dispose();
    _yearsOfServiceMonthCtrl.dispose();
    _counterpartyCtrl.dispose();
    _descriptionCtrl.dispose();
    _compensationCtrl.dispose();
    _processingCostCtrl.dispose();
    super.dispose();
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
    final existing = widget.existing;

    final record = AccidentRecord(
      id: existing?.id,
      no:
          existing?.no ??
          (service.records.map((r) => r.no).fold(0, (a, b) => a > b ? a : b) +
              1),
      office: _office,
      team: _team,
      accidentType: _accidentType,
      partsCause: _accidentType == AccidentType.parts ? _partsCause : null,
      occurredAt: _occurredAt,
      location: _locationCtrl.text.trim(),
      driverName: _driverNameCtrl.text.trim(),
      employeeNumber: _employeeNumberCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text),
      yearsOfServiceYear: int.tryParse(_yearsOfServiceYearCtrl.text),
      yearsOfServiceMonth: int.tryParse(_yearsOfServiceMonthCtrl.text),
      counterparty: _counterpartyCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      insurance: _insurance,
      compensationAmount: double.tryParse(_compensationCtrl.text) ?? 0,
      processingCost: double.tryParse(_processingCostCtrl.text) ?? 0,
      causeAnalysis: existing?.causeAnalysis,
      status: existing?.status ?? RecordStatus.reported,
      isMigrated: existing?.isMigrated ?? false,
      createdBy: existing?.createdBy ?? '',
    );

    if (_isEdit) {
      await service.updateRecord(record);
    } else {
      await service.addRecord(record);
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
                _sectionCard('ドライバー情報', [
                  _textField(_driverNameCtrl, '氏名'),
                  const SizedBox(height: 12),
                  _textField(_employeeNumberCtrl, '社員番号'),
                  const SizedBox(height: 12),
                  _textField(
                    _ageCtrl,
                    '年齢',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          _yearsOfServiceYearCtrl,
                          '勤続年数（年）',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _textField(
                          _yearsOfServiceMonthCtrl,
                          '勤続年数（月）',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionCard('金額・保険情報', [
                  _textField(
                    _compensationCtrl,
                    '賠償金額（支払金額）',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    _processingCostCtrl,
                    '事故処理諸費用',
                    keyboardType: TextInputType.number,
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
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$labelを入力してください' : null
          : null,
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
