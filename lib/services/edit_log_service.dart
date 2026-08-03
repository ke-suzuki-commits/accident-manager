import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/accident_record.dart';
import '../models/edit_log.dart';

/// 事故記録に対する新規登録・編集・削除の証跡(監査ログ)を扱うサービス。
///
/// 【重要】ログは改ざん防止のため追記専用(create only)とする。
/// Firestoreセキュリティルール側でも`edit_logs`コレクションへの
/// update/deleteをクライアントから禁止すること。
class EditLogService {
  static const String collectionName = 'edit_logs';

  final FirebaseFirestore _firestore;

  EditLogService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<void> logCreate({
    required AccidentRecord record,
    required String editorUid,
    required String editorName,
    required String editorEmail,
  }) async {
    final log = EditLog(
      recordId: record.id,
      recordNo: record.no,
      action: EditAction.create,
      editorUid: editorUid,
      editorName: editorName,
      editorEmail: editorEmail,
      timestamp: DateTime.now(),
    );
    await _collection.add(log.toMap());
  }

  Future<void> logUpdate({
    required AccidentRecord before,
    required AccidentRecord after,
    required String editorUid,
    required String editorName,
    required String editorEmail,
  }) async {
    final changes = _diff(before, after);
    if (changes.isEmpty) return;
    final log = EditLog(
      recordId: after.id,
      recordNo: after.no,
      action: EditAction.update,
      editorUid: editorUid,
      editorName: editorName,
      editorEmail: editorEmail,
      timestamp: DateTime.now(),
      changes: changes,
    );
    await _collection.add(log.toMap());
  }

  Future<void> logDelete({
    required AccidentRecord record,
    required String editorUid,
    required String editorName,
    required String editorEmail,
  }) async {
    final log = EditLog(
      recordId: record.id,
      recordNo: record.no,
      action: EditAction.delete,
      editorUid: editorUid,
      editorName: editorName,
      editorEmail: editorEmail,
      timestamp: DateTime.now(),
    );
    await _collection.add(log.toMap());
  }

  /// 指定した事故記録に対する編集履歴を新しい順で取得する。
  /// (record_idの単純where検索のみ。orderByは複合インデックスを
  ///  要求するため使わず、取得後にメモリ上でソートする)
  Future<List<EditLog>> getLogsForRecord(String recordId) async {
    final snap = await _collection
        .where('record_id', isEqualTo: recordId)
        .get();
    final logs = snap.docs.map((d) => EditLog.fromMap(d.id, d.data())).toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  List<FieldChange> _diff(AccidentRecord before, AccidentRecord after) {
    final changes = <FieldChange>[];
    void check(String label, String oldV, String newV) {
      final o = oldV.isEmpty ? '(空欄)' : oldV;
      final n = newV.isEmpty ? '(空欄)' : newV;
      if (o != n) {
        changes.add(FieldChange(fieldLabel: label, oldValue: o, newValue: n));
      }
    }

    check('発生部署', before.office.label, after.office.label);
    check('班', before.team.label, after.team.label);
    check('発生区分', before.accidentType.label, after.accidentType.label);
    check(
      '発生要因',
      before.partsCause?.label ?? '',
      after.partsCause?.label ?? '',
    );
    check(
      '発生日時',
      _fmtDateTime(before.occurredAt),
      _fmtDateTime(after.occurredAt),
    );
    check('発生場所', before.location, after.location);
    check('発生内容', before.description, after.description);
    check('氏名', before.driverName, after.driverName);
    check('社員番号', before.employeeNumber, after.employeeNumber);
    check('年齢', before.age?.toString() ?? '', after.age?.toString() ?? '');
    check(
      '勤続年数',
      _fmtYm(before.yearsOfServiceYear, before.yearsOfServiceMonth),
      _fmtYm(after.yearsOfServiceYear, after.yearsOfServiceMonth),
    );
    check(
      '業務経験年数',
      _fmtYm(before.yearsOfExperienceYear, before.yearsOfExperienceMonth),
      _fmtYm(after.yearsOfExperienceYear, after.yearsOfExperienceMonth),
    );
    check('相手方/荷主', before.counterparty, after.counterparty);
    check('保険有無', before.insurance.label, after.insurance.label);
    check(
      '賠償金額',
      _fmtMoney(before.compensationAmount),
      _fmtMoney(after.compensationAmount),
    );
    check(
      '事故処理諸費用',
      _fmtMoney(before.processingCost),
      _fmtMoney(after.processingCost),
    );
    check('進捗', before.status.label, after.status.label);
    return changes;
  }

  String _fmtDateTime(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtMoney(double v) {
    if (v == 0) return '';
    return '¥${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtYm(int? y, int? m) {
    if (y == null && m == null) return '';
    return '${y ?? 0}年${m ?? 0}ヶ月';
  }
}
