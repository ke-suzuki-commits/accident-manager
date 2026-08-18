import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/accident_master.dart';
import '../models/team_master.dart';
import '../utils/kana_normalize.dart';

/// 班マスタ(現在の班長・メンバー構成)の管理サービス。
class TeamMasterService extends ChangeNotifier {
  static const String collectionName = 'team_masters';

  final FirebaseFirestore _firestore;
  List<TeamMaster> _teams = [];
  bool _isLoading = true;
  String? _error;

  TeamMasterService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  List<TeamMaster> get teams => List.unmodifiable(_teams);
  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<void> loadTeams() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _collection.get();
      _teams = snap.docs
          .map((d) => TeamMaster.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      _error = '班マスタの読み込みに失敗しました: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 指定の班の班マスタ情報(未設定なら空のTeamMaster)
  TeamMaster masterFor(Team team) {
    for (final t in _teams) {
      if (t.team == team) return t;
    }
    return TeamMaster(team: team);
  }

  /// 指定の班の班長名(未設定なら空文字)
  String leaderNameFor(Team team) => masterFor(team).leaderName;

  /// 氏名の正規化(全角半角カナ統一・前後空白除去)。
  /// 事故記録側の運転者氏名と、班マスタ側の氏名の表記揺れを吸収するために使う。
  String _normalize(String name) => normalizeHalfWidthKana(name.trim());

  /// 氏名から所属する班を検索する(都度突き合わせ方式)。
  /// 事故記録の運転者氏名(driverName)をキーに、現在の班マスタと照合し、
  /// 現在の所属班を求める。見つからない場合はnullを返す。
  Team? findTeamByMemberName(String name) {
    final target = _normalize(name);
    if (target.isEmpty) return null;
    for (final t in _teams) {
      for (final m in t.allMemberNames) {
        if (_normalize(m) == target) return t.team;
      }
    }
    return null;
  }

  Future<void> saveTeamMaster({
    required Team team,
    required String leaderName,
    required List<String> memberNames,
    required String updatedBy,
  }) async {
    final cleanedMembers = memberNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final master = TeamMaster(
      team: team,
      leaderName: leaderName.trim(),
      memberNames: cleanedMembers,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
    try {
      await _collection.doc(team.name).set(master.toMap());
      final idx = _teams.indexWhere((t) => t.team == team);
      if (idx != -1) {
        _teams[idx] = master;
      } else {
        _teams.add(master);
      }
      notifyListeners();
    } catch (e) {
      _error = '班マスタの保存に失敗しました: $e';
      notifyListeners();
      rethrow;
    }
  }
}
