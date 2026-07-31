// 事故分類マスタ定義（アイデックス社内独自基準）
// Excelの「発生部署」「発生区分」「部品事故の発生要因」列構造をそのまま反映

/// 発生部署（事故が発生した部門）
enum OfficeDept {
  charter('傭車'),
  first('輸送1課'),
  second('輸送2課'),
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

  /// 庸車(傭車)扱いの事故かどうか。
  /// 役員要望により「庸車事故」と「自社事故」を分けて集計するための判定軸。
  /// 発生部署が「傭車」の場合のみ庸車事故とし、それ以外は自社事故として扱う。
  bool get isCharter => this == OfficeDept.charter;
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

/// 班（社内の小集団活動における班単位。A班〜O班）
/// 役員要望により、班ごとの月次事故集計を可能にするための分類軸として追加。
enum Team {
  a('A班'),
  b('B班'),
  c('C班'),
  d('D班'),
  e('E班'),
  f('F班'),
  g('G班'),
  h('H班'),
  i('I班'),
  j('J班'),
  k('K班'),
  l('L班'),
  m('M班'),
  n('N班'),
  o('O班'),
  unassigned('未設定');

  final String label;
  const Team(this.label);

  static Team fromLabel(String? label) {
    if (label == null) return Team.unassigned;
    return Team.values.firstWhere(
      (e) => e.label == label,
      orElse: () => Team.unassigned,
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
