/// 事故記録に対する操作の種別。
enum EditAction {
  create('新規登録'),
  update('編集'),
  delete('削除');

  final String label;
  const EditAction(this.label);

  static EditAction fromName(String? name) {
    return EditAction.values.firstWhere(
      (e) => e.name == name,
      orElse: () => EditAction.update,
    );
  }
}

/// 1項目分の変更内容(証跡管理用)。
class FieldChange {
  final String fieldLabel;
  final String oldValue;
  final String newValue;

  const FieldChange({
    required this.fieldLabel,
    required this.oldValue,
    required this.newValue,
  });

  Map<String, dynamic> toMap() => {
    'field_label': fieldLabel,
    'old_value': oldValue,
    'new_value': newValue,
  };

  factory FieldChange.fromMap(Map<String, dynamic> map) {
    return FieldChange(
      fieldLabel: (map['field_label'] as String?) ?? '',
      oldValue: (map['old_value'] as String?) ?? '',
      newValue: (map['new_value'] as String?) ?? '',
    );
  }
}

/// 事故記録の作成・編集・削除の証跡(監査ログ)。
/// Firestoreの`edit_logs`コレクションに保存され、一度作成したら
/// クライアントからの更新・削除は行わない(改ざん防止のため追記専用)。
class EditLog {
  final String? id;
  final String recordId;
  final int recordNo;
  final EditAction action;
  final String editorUid;
  final String editorName;
  final String editorEmail;
  final DateTime timestamp;
  final List<FieldChange> changes;

  const EditLog({
    this.id,
    required this.recordId,
    required this.recordNo,
    required this.action,
    required this.editorUid,
    required this.editorName,
    required this.editorEmail,
    required this.timestamp,
    this.changes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'record_id': recordId,
      'record_no': recordNo,
      'action': action.name,
      'editor_uid': editorUid,
      'editor_name': editorName,
      'editor_email': editorEmail,
      'timestamp': timestamp.toIso8601String(),
      'changes': changes.map((c) => c.toMap()).toList(),
    };
  }

  factory EditLog.fromMap(String id, Map<String, dynamic> map) {
    DateTime timestamp;
    final rawTs = map['timestamp'];
    if (rawTs is String) {
      timestamp = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }
    final rawChanges = map['changes'];
    final changes = <FieldChange>[];
    if (rawChanges is List) {
      for (final c in rawChanges) {
        if (c is Map<String, dynamic>) {
          changes.add(FieldChange.fromMap(c));
        } else if (c is Map) {
          changes.add(FieldChange.fromMap(Map<String, dynamic>.from(c)));
        }
      }
    }
    return EditLog(
      id: id,
      recordId: (map['record_id'] as String?) ?? '',
      recordNo: (map['record_no'] as num?)?.toInt() ?? 0,
      action: EditAction.fromName(map['action'] as String?),
      editorUid: (map['editor_uid'] as String?) ?? '',
      editorName: (map['editor_name'] as String?) ?? '不明',
      editorEmail: (map['editor_email'] as String?) ?? '',
      timestamp: timestamp,
      changes: changes,
    );
  }
}
