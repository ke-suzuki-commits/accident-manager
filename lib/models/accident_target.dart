import '../models/accident_master.dart';

/// 事故目標のスコープ(全社 or 特定の班)。
class TargetScope {
  /// 全社目標を表す特別な値。班別目標はTeamのnameを使う。
  static const String company = 'company';

  static String forTeam(Team team) => team.name;

  static bool isCompany(String scope) => scope == company;
}

/// 年度ごとの事故件数目標(全社 or 班別)。
/// Firestoreの`accident_targets`コレクションに保存。
/// ドキュメントID: `{fiscalYear}_{scope}` (例: `2026_company`, `2026_a`)
class AccidentTarget {
  final String? id;
  final int fiscalYear;
  final String scope; // TargetScope.company または Team.name
  final int targetCount;
  final DateTime? updatedAt;
  final String updatedBy;

  const AccidentTarget({
    this.id,
    required this.fiscalYear,
    required this.scope,
    required this.targetCount,
    this.updatedAt,
    this.updatedBy = '',
  });

  static String buildId(int fiscalYear, String scope) => '${fiscalYear}_$scope';

  bool get isCompanyWide => TargetScope.isCompany(scope);

  Map<String, dynamic> toMap() {
    return {
      'fiscal_year': fiscalYear,
      'scope': scope,
      'target_count': targetCount,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  factory AccidentTarget.fromMap(String id, Map<String, dynamic> map) {
    DateTime? updatedAt;
    final raw = map['updated_at'];
    if (raw is String) updatedAt = DateTime.tryParse(raw);
    return AccidentTarget(
      id: id,
      fiscalYear: (map['fiscal_year'] as num?)?.toInt() ?? 0,
      scope: (map['scope'] as String?) ?? TargetScope.company,
      targetCount: (map['target_count'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
      updatedBy: (map['updated_by'] as String?) ?? '',
    );
  }
}
