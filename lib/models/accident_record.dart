import 'package:uuid/uuid.dart';
import 'accident_master.dart';
import '../utils/kana_normalize.dart';

/// 事故の発生者(起因者)情報1名分。
/// ドライバーだけでなく、事務員・倉庫作業者等が事故を発生させる
/// ケースもあるため「発生者」という中立的な名称にしている。
/// また、起因者が複数名にわたる事故(例: 積み込み作業での複数人の連携ミス等)
/// にも対応するため、AccidentRecord側ではこれを`List<PersonInvolved>`として
/// 複数名保持する。
class PersonInvolved {
  final String name; // 氏名
  final PersonRole role; // 役職/立場(運転者・事務員・倉庫作業者・管理者)
  final String employeeNumber; // 社員番号
  final int? age; // 年齢
  final int? yearsOfServiceYear; // 勤続年数(年)
  final int? yearsOfServiceMonth; // 勤続年数(月)
  final int? yearsOfExperienceYear; // 業務経験年数(年)
  final int? yearsOfExperienceMonth; // 業務経験年数(月)

  const PersonInvolved({
    this.name = '',
    this.role = PersonRole.driver,
    this.employeeNumber = '',
    this.age,
    this.yearsOfServiceYear,
    this.yearsOfServiceMonth,
    this.yearsOfExperienceYear,
    this.yearsOfExperienceMonth,
  });

  // 注: roleは常にデフォルト値(運転者)を持つため、単体での選択のみでは
  // 「入力済み」とは判定しない(氏名等が全て未入力の場合は依然として空発生者欄として扱う)。
  bool get isEmpty =>
      name.isEmpty &&
      employeeNumber.isEmpty &&
      age == null &&
      yearsOfServiceYear == null &&
      yearsOfServiceMonth == null &&
      yearsOfExperienceYear == null &&
      yearsOfExperienceMonth == null;

  Map<String, dynamic> toMap() => {
    'name': name,
    'role': role.name,
    'employeeNumber': employeeNumber,
    'age': age,
    'yearsOfServiceYear': yearsOfServiceYear,
    'yearsOfServiceMonth': yearsOfServiceMonth,
    'yearsOfExperienceYear': yearsOfExperienceYear,
    'yearsOfExperienceMonth': yearsOfExperienceMonth,
  };

  factory PersonInvolved.fromMap(Map<dynamic, dynamic> map) {
    return PersonInvolved(
      // 半角カタカナの濁点/半濁点による文字化け(豆腐表示)を防ぐため、
      // 読み込み時に全角へ正規化する。
      name: normalizeHalfWidthKana(map['name'] as String? ?? ''),
      // 旧データ(役職導入以前の発生者)にはroleが存在しないため、
      // その場合は「運転者」として扱う(後方互換。従来の集計対象が
      // すべて運転者の事故であったため、従来の集計結果を変えないようにする目的)。
      role: PersonRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => PersonRole.driver,
      ),
      employeeNumber: map['employeeNumber'] as String? ?? '',
      age: map['age'] as int?,
      yearsOfServiceYear: map['yearsOfServiceYear'] as int?,
      yearsOfServiceMonth: map['yearsOfServiceMonth'] as int?,
      yearsOfExperienceYear: map['yearsOfExperienceYear'] as int?,
      yearsOfExperienceMonth: map['yearsOfExperienceMonth'] as int?,
    );
  }

  PersonInvolved copyWith({
    String? name,
    PersonRole? role,
    String? employeeNumber,
    int? age,
    int? yearsOfServiceYear,
    int? yearsOfServiceMonth,
    int? yearsOfExperienceYear,
    int? yearsOfExperienceMonth,
  }) {
    return PersonInvolved(
      name: name ?? this.name,
      role: role ?? this.role,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      age: age ?? this.age,
      yearsOfServiceYear: yearsOfServiceYear ?? this.yearsOfServiceYear,
      yearsOfServiceMonth: yearsOfServiceMonth ?? this.yearsOfServiceMonth,
      yearsOfExperienceYear:
          yearsOfExperienceYear ?? this.yearsOfExperienceYear,
      yearsOfExperienceMonth:
          yearsOfExperienceMonth ?? this.yearsOfExperienceMonth,
    );
  }
}

/// なぜなぜ分析（4回）＋真因
class CauseAnalysis {
  final String why1;
  final String why2;
  final String why3;
  final String why4;
  final String rootCause;
  final bool isAiDraft; // AIが生成したドラフトのままか
  final String editedBy; // 最終確定した管理者名

  const CauseAnalysis({
    this.why1 = '',
    this.why2 = '',
    this.why3 = '',
    this.why4 = '',
    this.rootCause = '',
    this.isAiDraft = false,
    this.editedBy = '',
  });

  bool get isEmpty =>
      why1.isEmpty &&
      why2.isEmpty &&
      why3.isEmpty &&
      why4.isEmpty &&
      rootCause.isEmpty;

  bool get isComplete =>
      why1.isNotEmpty &&
      why2.isNotEmpty &&
      why3.isNotEmpty &&
      why4.isNotEmpty &&
      rootCause.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'why1': why1,
    'why2': why2,
    'why3': why3,
    'why4': why4,
    'rootCause': rootCause,
    'isAiDraft': isAiDraft,
    'editedBy': editedBy,
  };

  factory CauseAnalysis.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const CauseAnalysis();
    // 半角カタカナの濁点/半濁点が文字化け(豆腐表示)する不具合を防ぐため、
    // 読み込み時に全角へ正規化する(既存データにも自動適用され、
    // データ移行なしで表示上の不具合が解消される)。
    return CauseAnalysis(
      why1: normalizeHalfWidthKana(map['why1'] as String? ?? ''),
      why2: normalizeHalfWidthKana(map['why2'] as String? ?? ''),
      why3: normalizeHalfWidthKana(map['why3'] as String? ?? ''),
      why4: normalizeHalfWidthKana(map['why4'] as String? ?? ''),
      rootCause: normalizeHalfWidthKana(map['rootCause'] as String? ?? ''),
      isAiDraft: map['isAiDraft'] as bool? ?? false,
      editedBy: normalizeHalfWidthKana(map['editedBy'] as String? ?? ''),
    );
  }

  CauseAnalysis copyWith({
    String? why1,
    String? why2,
    String? why3,
    String? why4,
    String? rootCause,
    bool? isAiDraft,
    String? editedBy,
  }) {
    return CauseAnalysis(
      why1: why1 ?? this.why1,
      why2: why2 ?? this.why2,
      why3: why3 ?? this.why3,
      why4: why4 ?? this.why4,
      rootCause: rootCause ?? this.rootCause,
      isAiDraft: isAiDraft ?? this.isAiDraft,
      editedBy: editedBy ?? this.editedBy,
    );
  }
}

/// 事故後対応の実績（課長面談・班ミーティング）
/// いずれの項目も任意入力(未実施の場合は空/nullのまま保存可)。
class FollowUpRecord {
  final DateTime? interviewDate; // 面談実施日
  final String interviewerName; // 面談担当者(課長)氏名
  final DateTime? meetingDate; // 班ミーティング実施日

  const FollowUpRecord({
    this.interviewDate,
    this.interviewerName = '',
    this.meetingDate,
  });

  bool get isInterviewDone => interviewDate != null;
  bool get isMeetingDone => meetingDate != null;
  bool get isComplete => isInterviewDone && isMeetingDone;
  bool get isEmpty =>
      interviewDate == null && interviewerName.isEmpty && meetingDate == null;

  Map<String, dynamic> toMap() => {
    'interviewDate': interviewDate?.toIso8601String(),
    'interviewerName': interviewerName,
    'meetingDate': meetingDate?.toIso8601String(),
  };

  factory FollowUpRecord.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const FollowUpRecord();
    return FollowUpRecord(
      interviewDate: map['interviewDate'] != null
          ? DateTime.parse(map['interviewDate'] as String)
          : null,
      interviewerName: normalizeHalfWidthKana(
        map['interviewerName'] as String? ?? '',
      ),
      meetingDate: map['meetingDate'] != null
          ? DateTime.parse(map['meetingDate'] as String)
          : null,
    );
  }

  FollowUpRecord copyWith({
    DateTime? interviewDate,
    bool clearInterviewDate = false,
    String? interviewerName,
    DateTime? meetingDate,
    bool clearMeetingDate = false,
  }) {
    return FollowUpRecord(
      interviewDate: clearInterviewDate
          ? null
          : (interviewDate ?? this.interviewDate),
      interviewerName: interviewerName ?? this.interviewerName,
      meetingDate: clearMeetingDate ? null : (meetingDate ?? this.meetingDate),
    );
  }
}

/// 事故記録メインエンティティ
class AccidentRecord {
  final String id;
  // 事故No.(自社(有責)/庸車(有責)の区分別連番)。
  // 無責・責任区分不明の事故は採番対象外のためnull。
  // (旧仕様では全区分共通の単一連番だったが、役員要望により区分別に変更)
  final int? no;
  final OfficeDept office; // 発生部署
  final Team team; // 班（小集団活動の班単位）
  final AccidentType accidentType; // 発生区分
  final Responsibility responsibility; // 責任区分（有責/無責/責任区分不明）
  final PartsAccidentCause? partsCause; // 部品事故発生要因（部品事故の場合のみ）
  final DateTime occurredAt; // 発生日時
  final int fiscalYear; // 年度（4月始まり）
  final int fiscalMonth; // 発生月（1-12）
  final String location; // 発生場所
  // 発生者(起因者)情報。ドライバーに限らず事務員・倉庫作業者等も対象と
  // なるため「発生者」という中立的な名称にしている。起因者が複数名の
  // 場合(例:複数人の連携ミス)にも対応するためリストで保持する。
  final List<PersonInvolved> involvedPersons;
  final InsuranceStatus insurance; // 保険有無
  final double compensationAmount; // 賠償金額(支払金額)
  final double processingCost; // 事故処理諸費用
  final String counterparty; // 荷主(相手方)
  final String description; // 発生内容
  final CauseAnalysis causeAnalysis; // なぜなぜ分析＋真因
  final FollowUpRecord followUp; // 事故後対応の実績（課長面談・班ミーティング）
  final RecordStatus status; // 進捗ステータス
  final List<String> photoUrls; // 現場写真
  final bool isMigrated; // Excel移行データかどうか
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccidentRecord({
    String? id,
    this.no,
    required this.office,
    this.team = Team.unassigned,
    required this.accidentType,
    this.responsibility = Responsibility.atFault,
    this.partsCause,
    required this.occurredAt,
    int? fiscalYear,
    int? fiscalMonth,
    this.location = '',
    List<PersonInvolved>? involvedPersons,
    this.insurance = InsuranceStatus.unknown,
    this.compensationAmount = 0,
    this.processingCost = 0,
    this.counterparty = '',
    this.description = '',
    CauseAnalysis? causeAnalysis,
    FollowUpRecord? followUp,
    this.status = RecordStatus.reported,
    this.photoUrls = const [],
    this.isMigrated = false,
    this.createdBy = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       fiscalYear = fiscalYear ?? calcFiscalYear(occurredAt),
       fiscalMonth = fiscalMonth ?? occurredAt.month,
       involvedPersons = involvedPersons ?? const [],
       causeAnalysis = causeAnalysis ?? const CauseAnalysis(),
       followUp = followUp ?? const FollowUpRecord(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 日本の運送業でよく使われる4月始まり年度を算出
  static int calcFiscalYear(DateTime date) {
    return date.month >= 4 ? date.year : date.year - 1;
  }

  /// 事故No.の採番区分(自社(有責)/庸車(有責))。
  /// 無責・責任区分不明の場合はnull(採番対象外)。
  NumberingCategory? get numberingCategory =>
      numberingCategoryOf(office: office, responsibility: responsibility);

  /// 発生者が1名も登録されていないか。
  bool get hasNoInvolvedPerson => involvedPersons.isEmpty;

  /// 表示用: 発生者氏名をカンマ区切りで連結したもの。
  /// (一覧・検索・常習者分析など、複数名を1文字列として扱いたい箇所で使用)
  String get involvedNamesText => involvedPersons
      .map((p) => p.name)
      .where((n) => n.isNotEmpty)
      .join('、');

  Map<String, dynamic> toMap() => {
    'id': id,
    'no': no,
    'office': office.name,
    'team': team.name,
    'accidentType': accidentType.name,
    'responsibility': responsibility.name,
    'partsCause': partsCause?.name,
    'occurredAt': occurredAt.toIso8601String(),
    'fiscalYear': fiscalYear,
    'fiscalMonth': fiscalMonth,
    'location': location,
    'involvedPersons': involvedPersons.map((p) => p.toMap()).toList(),
    'insurance': insurance.name,
    'compensationAmount': compensationAmount,
    'processingCost': processingCost,
    'counterparty': counterparty,
    'description': description,
    'causeAnalysis': causeAnalysis.toMap(),
    'followUp': followUp.toMap(),
    'status': status.name,
    'photoUrls': photoUrls,
    'isMigrated': isMigrated,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AccidentRecord.fromMap(Map<dynamic, dynamic> map) {
    return AccidentRecord(
      id: map['id'] as String?,
      // 旧仕様(全区分共通の単一連番)からの移行データも含め、(map['no'] as num?)で
      // 数値として安全に読み取る。無責等でno未採番のデータはnullのまま保持する。
      no: (map['no'] as num?)?.toInt(),
      office: OfficeDept.values.firstWhere(
        (e) => e.name == map['office'],
        orElse: () => OfficeDept.unknown,
      ),
      // 既存データ(班導入以前のExcel移行データ等)にはteamが存在しないため、
      // その場合は「未設定」として扱う(後方互換)。
      team: Team.values.firstWhere(
        (e) => e.name == map['team'],
        orElse: () => Team.unassigned,
      ),
      accidentType: AccidentType.values.firstWhere(
        (e) => e.name == map['accidentType'],
        orElse: () => AccidentType.property,
      ),
      // 既存データ(責任区分導入以前のもの)にはresponsibilityが存在しないため、
      // その場合は「有責」として扱う(後方互換。従来の集計結果を変えないため)。
      responsibility: Responsibility.values.firstWhere(
        (e) => e.name == map['responsibility'],
        orElse: () => Responsibility.atFault,
      ),
      partsCause: map['partsCause'] != null
          ? PartsAccidentCause.values.firstWhere(
              (e) => e.name == map['partsCause'],
              orElse: () => PartsAccidentCause.other,
            )
          : null,
      occurredAt: DateTime.parse(map['occurredAt'] as String),
      fiscalYear: map['fiscalYear'] as int?,
      fiscalMonth: map['fiscalMonth'] as int?,
      // 半角カタカナの濁点/半濁点による文字化け(豆腐表示)を防ぐため、
      // 読み込み時に全角へ正規化する(Excel移行データ・既存Firestoreデータにも
      // 自動適用され、データ移行スクリプトなしで表示不具合が解消される)。
      location: normalizeHalfWidthKana(map['location'] as String? ?? ''),
      involvedPersons: _parseInvolvedPersons(map),
      insurance: InsuranceStatus.values.firstWhere(
        (e) => e.name == map['insurance'],
        orElse: () => InsuranceStatus.unknown,
      ),
      compensationAmount: (map['compensationAmount'] as num?)?.toDouble() ?? 0,
      processingCost: (map['processingCost'] as num?)?.toDouble() ?? 0,
      counterparty: normalizeHalfWidthKana(
        map['counterparty'] as String? ?? '',
      ),
      description: normalizeHalfWidthKana(map['description'] as String? ?? ''),
      causeAnalysis: CauseAnalysis.fromMap(map['causeAnalysis'] as Map?),
      followUp: FollowUpRecord.fromMap(map['followUp'] as Map?),
      // 旧バージョンに存在した「承認済み(approved)」は現バージョンの
      // enumから削除したため、該当データは分析完了済みとして扱う。
      status: RecordStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RecordStatus.analyzed,
      ),
      photoUrls: (map['photoUrls'] as List?)?.cast<String>() ?? const [],
      isMigrated: map['isMigrated'] as bool? ?? false,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// 発生者情報の読み込み(後方互換対応)。
  /// 新形式: map['involvedPersons'] (List) が存在すればそれを使用する。
  /// 旧形式: 単一の発生者(driverName/employeeNumber/age/勤続年数等)の
  /// フィールドが個別に保存されている既存データ(複数名対応前に登録された
  /// 全レコード)は、1名分のPersonInvolvedとして自動的に読み込む。
  /// これにより、データ移行スクリプトなしで既存データがそのまま
  /// 「発生者1名」として表示・編集できる。
  static List<PersonInvolved> _parseInvolvedPersons(Map<dynamic, dynamic> map) {
    final list = map['involvedPersons'] as List?;
    if (list != null) {
      return list
          .map((e) => PersonInvolved.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    }
    // 旧形式からの後方互換読み込み。
    final legacyName = normalizeHalfWidthKana(
      map['driverName'] as String? ?? '',
    );
    final legacyEmpNo = map['employeeNumber'] as String? ?? '';
    final legacyAge = map['age'] as int?;
    final legacyServiceYear = map['yearsOfServiceYear'] as int?;
    final legacyServiceMonth = map['yearsOfServiceMonth'] as int?;
    final legacyExpYear = map['yearsOfExperienceYear'] as int?;
    final legacyExpMonth = map['yearsOfExperienceMonth'] as int?;
    final legacyPerson = PersonInvolved(
      name: legacyName,
      employeeNumber: legacyEmpNo,
      age: legacyAge,
      yearsOfServiceYear: legacyServiceYear,
      yearsOfServiceMonth: legacyServiceMonth,
      yearsOfExperienceYear: legacyExpYear,
      yearsOfExperienceMonth: legacyExpMonth,
    );
    return legacyPerson.isEmpty ? const [] : [legacyPerson];
  }

  AccidentRecord copyWith({
    int? no,
    OfficeDept? office,
    Team? team,
    AccidentType? accidentType,
    Responsibility? responsibility,
    PartsAccidentCause? partsCause,
    bool clearPartsCause = false,
    DateTime? occurredAt,
    String? location,
    List<PersonInvolved>? involvedPersons,
    InsuranceStatus? insurance,
    double? compensationAmount,
    double? processingCost,
    String? counterparty,
    String? description,
    CauseAnalysis? causeAnalysis,
    FollowUpRecord? followUp,
    RecordStatus? status,
    List<String>? photoUrls,
    bool? isMigrated,
    String? createdBy,
    // No.振り直し等、内容自体は変わらない機械的な更新の場合に
    // updatedAt(最終更新日時)を意図せず書き換えないためのフラグ。
    bool keepUpdatedAt = false,
  }) {
    final newOccurredAt = occurredAt ?? this.occurredAt;
    return AccidentRecord(
      id: id,
      no: no ?? this.no,
      office: office ?? this.office,
      team: team ?? this.team,
      accidentType: accidentType ?? this.accidentType,
      responsibility: responsibility ?? this.responsibility,
      partsCause: clearPartsCause ? null : (partsCause ?? this.partsCause),
      occurredAt: newOccurredAt,
      fiscalYear: calcFiscalYear(newOccurredAt),
      fiscalMonth: newOccurredAt.month,
      location: location ?? this.location,
      involvedPersons: involvedPersons ?? this.involvedPersons,
      insurance: insurance ?? this.insurance,
      compensationAmount: compensationAmount ?? this.compensationAmount,
      processingCost: processingCost ?? this.processingCost,
      counterparty: counterparty ?? this.counterparty,
      description: description ?? this.description,
      causeAnalysis: causeAnalysis ?? this.causeAnalysis,
      followUp: followUp ?? this.followUp,
      status: status ?? this.status,
      photoUrls: photoUrls ?? this.photoUrls,
      isMigrated: isMigrated ?? this.isMigrated,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
      updatedAt: keepUpdatedAt ? updatedAt : DateTime.now(),
    );
  }
}
