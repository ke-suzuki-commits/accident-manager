// 事故分類マスタ定義（アイデックス社内独自基準）
// Excelの「発生部署」「発生区分」「部品事故の発生要因」列構造をそのまま反映

/// 発生部署（事故が発生した部門）
enum OfficeDept {
  charter('傭車'),
  first('第一輸送部'),
  second('第二輸送部'),
  metal('メタル便'),
  warehouse('倉庫課'),
  unknown('責任区不明');

  final String label;
  const OfficeDept(this.label);

  static OfficeDept fromLabel(String label) {
    return OfficeDept.values.firstWhere(
      (e) => e.label == label,
      orElse: () => OfficeDept.unknown,
    );
  }
}

/// 発生区分（事故の種別）
enum AccidentType {
  traffic('交通事故'),
  property('物損事故'),
  parts('部品事故'),
  product('製品事故'),
  delivery('納入異常'),
  info('情報系'),
  labor('労災事故'),
  environment('環境事故'),
  ruleViolation('ルール違反'),
  claim('クレーム');

  final String label;
  const AccidentType(this.label);

  static AccidentType fromLabel(String label) {
    return AccidentType.values.firstWhere(
      (e) => e.label == label,
      orElse: () => AccidentType.property,
    );
  }
}

/// 部品事故の発生要因（発生区分＝部品事故の場合のみ選択）
enum PartsAccidentCause {
  adjacentProductCheck('隣接製品確認不足'),
  forkTipCheck('フォーク先確認不足'),
  sharpTurnStartStop('急旋回・急発進停止'),
  forkHeight('フォークの高さ不良'),
  forkInsertion('フォークの抜き差し不良'),
  stackingSeparation('段積み・切り離し'),
  driving('走行中'),
  loadShapeCheck('荷姿・周囲の確認不足'),
  loadCollapse('荷崩れ'),
  manualWork('手作業'),
  other('その他');

  final String label;
  const PartsAccidentCause(this.label);

  static PartsAccidentCause? fromLabel(String? label) {
    if (label == null) return null;
    for (final e in PartsAccidentCause.values) {
      if (e.label == label) return e;
    }
    return null;
  }
}

/// 進捗ステータス（速報登録 → 原因分析完了）
/// ※承認フローは本アプリのスコープ外のため廃止(2段階管理に変更)
enum RecordStatus {
  reported('速報登録'),
  analyzed('原因分析完了');

  final String label;
  const RecordStatus(this.label);

  static RecordStatus fromLabel(String label) {
    return RecordStatus.values.firstWhere(
      (e) => e.label == label,
      // 過去データに残っている旧ステータス「承認済み」は
      // 「原因分析完了」として扱う(データ移行時の後方互換)。
      orElse: () => RecordStatus.analyzed,
    );
  }
}

/// 保険適用有無
enum InsuranceStatus {
  yes('有'),
  no('無'),
  unknown('不明');

  final String label;
  const InsuranceStatus(this.label);

  static InsuranceStatus fromLabel(String? label) {
    if (label == null) return InsuranceStatus.unknown;
    return InsuranceStatus.values.firstWhere(
      (e) => e.label == label,
      orElse: () => InsuranceStatus.unknown,
    );
  }
}
