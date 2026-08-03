import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/accident_master.dart';
import '../models/accident_target.dart';

/// 年度事故件数目標(全社・班別)の管理サービス。
class AccidentTargetService extends ChangeNotifier {
  static const String collectionName = 'accident_targets';

  final FirebaseFirestore _firestore;
  List<AccidentTarget> _targets = [];
  bool _isLoading = true;
  String? _error;

  AccidentTargetService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  List<AccidentTarget> get targets => List.unmodifiable(_targets);
  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Future<void> loadTargets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _collection.get();
      _targets = snap.docs
          .map((d) => AccidentTarget.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      _error = '目標データの読み込みに失敗しました: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 指定年度の全社目標(未設定ならnull)
  AccidentTarget? companyTarget(int fiscalYear) {
    for (final t in _targets) {
      if (t.fiscalYear == fiscalYear && t.isCompanyWide) return t;
    }
    return null;
  }

  /// 指定年度・班の目標(未設定ならnull)
  AccidentTarget? teamTarget(int fiscalYear, Team team) {
    final scope = TargetScope.forTeam(team);
    for (final t in _targets) {
      if (t.fiscalYear == fiscalYear && t.scope == scope) return t;
    }
    return null;
  }

  /// 指定年度に設定済みの班別目標一覧
  List<AccidentTarget> teamTargetsForYear(int fiscalYear) {
    return _targets
        .where((t) => t.fiscalYear == fiscalYear && !t.isCompanyWide)
        .toList();
  }

  Future<void> setCompanyTarget({
    required int fiscalYear,
    required int targetCount,
    required String updatedBy,
  }) async {
    await _setTarget(
      fiscalYear: fiscalYear,
      scope: TargetScope.company,
      targetCount: targetCount,
      updatedBy: updatedBy,
    );
  }

  Future<void> setTeamTarget({
    required int fiscalYear,
    required Team team,
    required int targetCount,
    required String updatedBy,
  }) async {
    await _setTarget(
      fiscalYear: fiscalYear,
      scope: TargetScope.forTeam(team),
      targetCount: targetCount,
      updatedBy: updatedBy,
    );
  }

  Future<void> _setTarget({
    required int fiscalYear,
    required String scope,
    required int targetCount,
    required String updatedBy,
  }) async {
    final id = AccidentTarget.buildId(fiscalYear, scope);
    final target = AccidentTarget(
      id: id,
      fiscalYear: fiscalYear,
      scope: scope,
      targetCount: targetCount,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
    try {
      await _collection.doc(id).set(target.toMap());
      final idx = _targets.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _targets[idx] = target;
      } else {
        _targets.add(target);
      }
      notifyListeners();
    } catch (e) {
      _error = '目標の保存に失敗しました: $e';
      notifyListeners();
      rethrow;
    }
  }
}
