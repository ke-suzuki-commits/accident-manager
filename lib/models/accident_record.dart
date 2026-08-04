import 'package:uuid/uuid.dart';
import 'accident_master.dart';
import '../utils/kana_normalize.dart';

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
  final int no; // Excel由来の管理番号(通番)
  final OfficeDept office; // 発生部署
  final Team team; // 班（小集団活動の班単位）
  final AccidentType accidentType; // 発生区分
  final PartsAccidentCause? partsCause; // 部品事故発生要因（部品事故の場合のみ）
  final DateTime occurredAt; // 発生日時
  final int fiscalYear; // 年度（4月始まり）
  final int fiscalMonth; // 発生月（1-12）
  final String location; // 発生場所
  final String employeeNumber; // 社員番号
  final String driverName; // 名前
  final int? age; // 年齢
  final int? yearsOfServiceYear; // 勤続年数(年)
  final int? yearsOfServiceMonth; // 勤続年数(月)
  final int? yearsOfExperienceYear; // 業務経験年数(年)
  final int? yearsOfExperienceMonth; // 業務経験年数(月)
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
    required this.no,
    required this.office,
    this.team = Team.unassigned,
    required this.accidentType,
    this.partsCause,
    required this.occurredAt,
    int? fiscalYear,
    int? fiscalMonth,
    this.location = '',
    this.employeeNumber = '',
    this.driverName = '',
    this.age,
    this.yearsOfServiceYear,
    this.yearsOfServiceMonth,
    this.yearsOfExperienceYear,
    this.yearsOfExperienceMonth,
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
       causeAnalysis = causeAnalysis ?? const CauseAnalysis(),
       followUp = followUp ?? const FollowUpRecord(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 日本の運送業でよく使われる4月始まり年度を算出
  static int calcFiscalYear(DateTime date) {
    return date.month >= 4 ? date.year : date.year - 1;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'no': no,
    'office': office.name,
    'team': team.name,
    'accidentType': accidentType.name,
    'partsCause': partsCause?.name,
    'occurredAt': occurredAt.toIso8601String(),
    'fiscalYear': fiscalYear,
    'fiscalMonth': fiscalMonth,
    'location': location,
    'employeeNumber': employeeNumber,
    'driverName': driverName,
    'age': age,
    'yearsOfServiceYear': yearsOfServiceYear,
    'yearsOfServiceMonth': yearsOfServiceMonth,
    'yearsOfExperienceYear': yearsOfExperienceYear,
    'yearsOfExperienceMonth': yearsOfExperienceMonth,
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
      no: map['no'] as int? ?? 0,
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
      employeeNumber: map['employeeNumber'] as String? ?? '',
      driverName: normalizeHalfWidthKana(map['driverName'] as String? ?? ''),
      age: map['age'] as int?,
      yearsOfServiceYear: map['yearsOfServiceYear'] as int?,
      yearsOfServiceMonth: map['yearsOfServiceMonth'] as int?,
      yearsOfExperienceYear: map['yearsOfExperienceYear'] as int?,
      yearsOfExperienceMonth: map['yearsOfExperienceMonth'] as int?,
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

  AccidentRecord copyWith({
    int? no,
    OfficeDept? office,
    Team? team,
    AccidentType? accidentType,
    PartsAccidentCause? partsCause,
    bool clearPartsCause = false,
    DateTime? occurredAt,
    String? location,
    String? employeeNumber,
    String? driverName,
    int? age,
    int? yearsOfServiceYear,
    int? yearsOfServiceMonth,
    int? yearsOfExperienceYear,
    int? yearsOfExperienceMonth,
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
  }) {
    final newOccurredAt = occurredAt ?? this.occurredAt;
    return AccidentRecord(
      id: id,
      no: no ?? this.no,
      office: office ?? this.office,
      team: team ?? this.team,
      accidentType: accidentType ?? this.accidentType,
      partsCause: clearPartsCause ? null : (partsCause ?? this.partsCause),
      occurredAt: newOccurredAt,
      fiscalYear: calcFiscalYear(newOccurredAt),
      fiscalMonth: newOccurredAt.month,
      location: location ?? this.location,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      driverName: driverName ?? this.driverName,
      age: age ?? this.age,
      yearsOfServiceYear: yearsOfServiceYear ?? this.yearsOfServiceYear,
      yearsOfServiceMonth: yearsOfServiceMonth ?? this.yearsOfServiceMonth,
      yearsOfExperienceYear:
          yearsOfExperienceYear ?? this.yearsOfExperienceYear,
      yearsOfExperienceMonth:
          yearsOfExperienceMonth ?? this.yearsOfExperienceMonth,
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
      updatedAt: DateTime.now(),
    );
  }
}
