import '../models/accident_master.dart';

/// 班マスタ(現在の班編成情報)。
/// Firestoreの`team_masters`コレクションに保存。
/// ドキュメントID: `Team.name` (例: `a`, `b`, ... `o`)
///
/// 【設計方針】
/// - ドライバーはこのアプリを閲覧しないため、社員アカウント(AppUser)との
///   紐付けは行わず、氏名の文字列のみで管理する(ページを圧迫する社員番号等の
///   項目は持たせない)。
/// - 班長は1班につき常に1名の想定。
/// - 異動履歴は管理しない(常に「現在の班構成」のみを保持する)。
/// - 事故記録(AccidentRecord)との連携は、事故記録自体を書き換えるのではなく、
///   表示時に運転者氏名(driverName)をキーに班マスタと都度突き合わせる方式とする。
class TeamMaster {
  final Team team;
  final String leaderName;
  final List<String> memberNames;
  final DateTime? updatedAt;
  final String updatedBy;

  const TeamMaster({
    required this.team,
    this.leaderName = '',
    this.memberNames = const [],
    this.updatedAt,
    this.updatedBy = '',
  });

  /// メンバー一覧(班長を含む、表示用)。班長が先頭に来るよう並べる。
  List<String> get allMemberNames {
    final names = <String>[];
    final trimmedLeader = leaderName.trim();
    if (trimmedLeader.isNotEmpty) names.add(trimmedLeader);
    for (final m in memberNames) {
      final t = m.trim();
      if (t.isEmpty) continue;
      if (t == trimmedLeader) continue;
      names.add(t);
    }
    return names;
  }

  /// 班長を含む班の総人数
  int get memberCount => allMemberNames.length;

  bool get isEmpty => leaderName.trim().isEmpty && memberNames.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'team': team.name,
      'leader_name': leaderName,
      'member_names': memberNames,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  factory TeamMaster.fromMap(String id, Map<String, dynamic> map) {
    DateTime? updatedAt;
    final raw = map['updated_at'];
    if (raw is String) updatedAt = DateTime.tryParse(raw);
    final rawMembers = map['member_names'];
    final members = rawMembers is List
        ? rawMembers.map((e) => e.toString()).toList()
        : <String>[];
    return TeamMaster(
      team: Team.values.firstWhere(
        (t) => t.name == id,
        orElse: () => Team.unassigned,
      ),
      leaderName: (map['leader_name'] as String?) ?? '',
      memberNames: members,
      updatedAt: updatedAt,
      updatedBy: (map['updated_by'] as String?) ?? '',
    );
  }

  TeamMaster copyWith({
    String? leaderName,
    List<String>? memberNames,
    String? updatedBy,
  }) {
    return TeamMaster(
      team: team,
      leaderName: leaderName ?? this.leaderName,
      memberNames: memberNames ?? this.memberNames,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
