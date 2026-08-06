import 'package:flutter/foundation.dart';
import '../models/accident_master.dart';
import '../models/accident_record.dart';
import '../models/edit_log.dart';
import '../repositories/accident_repository.dart';
import 'edit_log_service.dart';

/// 複数事故を起こしている事故惹起者（多重事故者）の集計結果1件分。
/// 社員番号があればそれをキーに、無ければ氏名をキーにグルーピングする。
class RepeatOffender {
  final String driverName;
  final String employeeNumber;
  final List<AccidentRecord> records; // 発生日時が新しい順

  RepeatOffender({
    required this.driverName,
    required this.employeeNumber,
    required this.records,
  });

  int get count => records.length;
}

/// 事故記録の状態管理サービス（Provider経由でアプリ全体から利用）
class AccidentService extends ChangeNotifier {
  final AccidentRepository _repository;
  final EditLogService _editLogService;
  List<AccidentRecord> _records = [];
  // 初期値をtrueにしておくことで、Firestoreからのデータ取得が完了する前の
  // 一瞬「0件」という誤った空表示がダッシュボード等に出てしまう問題を防ぐ。
  bool _isLoading = true;
  String? _error;

  AccidentService(this._repository, {EditLogService? editLogService})
    : _editLogService = editLogService ?? EditLogService();

  List<AccidentRecord> get records => List.unmodifiable(_records);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRecords() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await _repository.getAll();
      _records.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    } catch (e) {
      _error = 'データの読み込みに失敗しました: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecord(
    AccidentRecord record, {
    required String editorUid,
    required String editorName,
    required String editorEmail,
  }) async {
    try {
      await _repository.save(record);
      _records.insert(0, record);
      _records.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      notifyListeners();
      // 証跡ログの記録失敗で本体保存まで失敗扱いにしないよう、
      // ログ書き込みは独立したtry-catchで囲む。
      try {
        await _editLogService.logCreate(
          record: record,
          editorUid: editorUid,
          editorName: editorName,
          editorEmail: editorEmail,
        );
      } catch (_) {
        // ログ記録の失敗は業務継続を優先し無視する(コンソールにのみ影響が残る)。
      }
    } catch (e) {
      _error = '保存に失敗しました: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateRecord(
    AccidentRecord record, {
    required String editorUid,
    required String editorName,
    required String editorEmail,
  }) async {
    try {
      final idx = _records.indexWhere((r) => r.id == record.id);
      final before = idx != -1 ? _records[idx] : null;
      await _repository.save(record);
      if (idx != -1) {
        _records[idx] = record;
      }
      notifyListeners();
      if (before != null) {
        try {
          await _editLogService.logUpdate(
            before: before,
            after: record,
            editorUid: editorUid,
            editorName: editorName,
            editorEmail: editorEmail,
          );
        } catch (_) {
          // ログ記録の失敗は業務継続を優先し無視する。
        }
      }
    } catch (e) {
      _error = '更新に失敗しました: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteRecord(
    String id, {
    required String editorUid,
    required String editorName,
    required String editorEmail,
  }) async {
    try {
      final idx = _records.indexWhere((r) => r.id == id);
      final record = idx != -1 ? _records[idx] : null;
      await _repository.delete(id);
      _records.removeWhere((r) => r.id == id);
      notifyListeners();
      if (record != null) {
        try {
          await _editLogService.logDelete(
            record: record,
            editorUid: editorUid,
            editorName: editorName,
            editorEmail: editorEmail,
          );
        } catch (_) {
          // ログ記録の失敗は業務継続を優先し無視する。
        }
      }
    } catch (e) {
      _error = '削除に失敗しました: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 指定した事故記録の編集履歴(証跡)を新しい順で取得する。
  Future<List<EditLog>> getEditLogs(String recordId) {
    return _editLogService.getLogsForRecord(recordId);
  }

  Future<void> importRecords(List<AccidentRecord> newRecords) async {
    try {
      await _repository.saveAll(newRecords);
      await loadRecords();
    } catch (e) {
      _error = 'インポートに失敗しました: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// 登録済みの全事故記録を「発生日時が古いもの順」にNo.1から振り直す。
  /// 手動採番のずれ・Excel移行データの不整合をまとめて解消するための
  /// 管理者向け一括処理。実行後は自動でloadRecords()により再読込する。
  /// 戻り値: 実際に振り直した件数（No.に変更が無かった件を除く）。
  Future<int> renumberAllByOccurredAt() async {
    try {
      final sorted = [..._records]
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      final updated = <AccidentRecord>[];
      for (var i = 0; i < sorted.length; i++) {
        final newNo = i + 1;
        if (sorted[i].no != newNo) {
          updated.add(sorted[i].copyWith(no: newNo, keepUpdatedAt: true));
        }
      }
      if (updated.isNotEmpty) {
        await _repository.saveAll(updated);
        await loadRecords();
      }
      return updated.length;
    } catch (e) {
      _error = 'No.の振り直しに失敗しました: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ---------- 集計・分析用ヘルパー ----------

  List<int> get availableFiscalYears {
    final years = _records.map((r) => r.fiscalYear).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<AccidentRecord> byFiscalYear(int fiscalYear) {
    return _records.where((r) => r.fiscalYear == fiscalYear).toList();
  }

  /// 集計対象(有責のみ)の記録一覧。
  /// 無責・責任区分不明の事故は、全体集計・班別集計などの「件数」カウントには
  /// 加算しない(役員要望)。一覧画面での閲覧・編集は引き続き全件対象。
  List<AccidentRecord> countableByFiscalYear(int fiscalYear) {
    return byFiscalYear(
      fiscalYear,
    ).where((r) => r.responsibility.isCountable).toList();
  }

  /// 指定年度の無責・責任区分不明の件数(モニター用)。
  int excludedCount(int fiscalYear) {
    return byFiscalYear(
      fiscalYear,
    ).where((r) => !r.responsibility.isCountable).length;
  }

  /// 指定年度の無責・責任区分不明の内訳(モニター用)。
  Map<Responsibility, int> excludedBreakdown(int fiscalYear) {
    final result = <Responsibility, int>{};
    for (final r in byFiscalYear(fiscalYear)) {
      if (!r.responsibility.isCountable) {
        result[r.responsibility] = (result[r.responsibility] ?? 0) + 1;
      }
    }
    return result;
  }

  /// 年度内の月別件数 (4月〜3月の順)。無責・責任区分不明は含まない。
  Map<int, int> monthlyCountByFiscalYear(int fiscalYear) {
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final result = {for (final m in months) m: 0};
    for (final r in countableByFiscalYear(fiscalYear)) {
      result[r.fiscalMonth] = (result[r.fiscalMonth] ?? 0) + 1;
    }
    return result;
  }

  /// 発生区分別件数。無責・責任区分不明は含まない。
  Map<AccidentType, int> typeBreakdown(int fiscalYear) {
    final result = <AccidentType, int>{};
    for (final r in countableByFiscalYear(fiscalYear)) {
      result[r.accidentType] = (result[r.accidentType] ?? 0) + 1;
    }
    return result;
  }

  /// 発生部署別件数。無責・責任区分不明は含まない。
  Map<OfficeDept, int> officeBreakdown(int fiscalYear) {
    final result = <OfficeDept, int>{};
    for (final r in countableByFiscalYear(fiscalYear)) {
      result[r.office] = (result[r.office] ?? 0) + 1;
    }
    return result;
  }

  /// 部品事故の発生要因別件数。無責・責任区分不明は含まない。
  Map<PartsAccidentCause, int> partsCauseBreakdown(int fiscalYear) {
    final result = <PartsAccidentCause, int>{};
    for (final r in countableByFiscalYear(fiscalYear)) {
      if (r.partsCause != null) {
        result[r.partsCause!] = (result[r.partsCause!] ?? 0) + 1;
      }
    }
    return result;
  }

  /// 原因分析未完了件数。無責・責任区分不明は含まない
  /// (ダッシュボードの「事故件数」カードと合計が一致するようにするため)。
  int uncompletedAnalysisCount(int fiscalYear) {
    return countableByFiscalYear(
      fiscalYear,
    ).where((r) => r.status == RecordStatus.reported).length;
  }

  /// 原因分析完了件数。無責・責任区分不明は含まない(同上の理由)。
  int analyzedCount(int fiscalYear) {
    return countableByFiscalYear(
      fiscalYear,
    ).where((r) => r.status == RecordStatus.analyzed).length;
  }

  /// 年度別総額（賠償金額＋事故処理諸費用の合計）
  /// ※　以前の「金額」入力欄は廃止したため、実際に入力される2項目で集計する。
  /// ※　無責・責任区分不明でも実際に賠償金・処理費用が発生している場合があるため、
  ///    金額集計はあえて除外対象にしない(件数カウントのみ除外する役員要望のため)。
  double totalAmount(int fiscalYear) {
    return byFiscalYear(
      fiscalYear,
    ).fold(0, (sum, r) => sum + r.compensationAmount + r.processingCost);
  }

  /// 班別件数（小集団活動の月次集計用）。無責・責任区分不明は含まない。
  Map<Team, int> teamBreakdown(int fiscalYear) {
    final result = <Team, int>{};
    for (final r in countableByFiscalYear(fiscalYear)) {
      result[r.team] = (result[r.team] ?? 0) + 1;
    }
    return result;
  }

  /// 班別・月別件数（班別の月次集計用）。無責・責任区分不明は含まない。
  Map<int, int> monthlyCountByTeam(int fiscalYear, Team team) {
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final result = {for (final m in months) m: 0};
    for (final r in countableByFiscalYear(
      fiscalYear,
    ).where((r) => r.team == team)) {
      result[r.fiscalMonth] = (result[r.fiscalMonth] ?? 0) + 1;
    }
    return result;
  }

  /// 庸車事故（発生部署＝僭車）の件数。無責・責任区分不明は含まない。
  int charterAccidentCount(int fiscalYear) {
    return countableByFiscalYear(
      fiscalYear,
    ).where((r) => r.office.isCharter).length;
  }

  /// 自社事故（発生部署＝僭車以外）の件数。無責・責任区分不明は含まない。
  int ownCompanyAccidentCount(int fiscalYear) {
    return countableByFiscalYear(
      fiscalYear,
    ).where((r) => !r.office.isCharter).length;
  }

  /// 庸車事故・自社事故の月別件数比較。無責・責任区分不明は含まない。
  /// 戻り値: {true: 庸車の月別件数, false: 自社の月別件数}
  Map<bool, Map<int, int>> charterVsOwnMonthlyComparison(int fiscalYear) {
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final charter = {for (final m in months) m: 0};
    final own = {for (final m in months) m: 0};
    for (final r in countableByFiscalYear(fiscalYear)) {
      if (r.office.isCharter) {
        charter[r.fiscalMonth] = (charter[r.fiscalMonth] ?? 0) + 1;
      } else {
        own[r.fiscalMonth] = (own[r.fiscalMonth] ?? 0) + 1;
      }
    }
    return {true: charter, false: own};
  }

  /// 年度比較用: 複数年度の月別件数
  Map<int, Map<int, int>> multiYearMonthlyComparison(List<int> fiscalYears) {
    return {for (final fy in fiscalYears) fy: monthlyCountByFiscalYear(fy)};
  }

  /// 前年度同月比較。指定年度の指定月(fiscalMonth: 1-12)における件数と、
  /// 前年度同月の件数を返す。
  /// 無責・責任区分不明は含まない。
  ({int current, int previous}) sameMonthYearOverYear(
    int fiscalYear,
    int fiscalMonth,
  ) {
    final current = countableByFiscalYear(
      fiscalYear,
    ).where((r) => r.fiscalMonth == fiscalMonth).length;
    final previous = countableByFiscalYear(
      fiscalYear - 1,
    ).where((r) => r.fiscalMonth == fiscalMonth).length;
    return (current: current, previous: previous);
  }

  /// 前年度との月別件数の並列比較(4月〜3月の順)。
  /// 戻り値: {true: 当年度の月別件数, false: 前年度の月別件数}
  Map<bool, Map<int, int>> yearOverYearMonthlyComparison(int fiscalYear) {
    return {
      true: monthlyCountByFiscalYear(fiscalYear),
      false: monthlyCountByFiscalYear(fiscalYear - 1),
    };
  }

  /// 複数事故を起こしている事故惹起者（多重事故者）を集計する。
  ///
  /// グルーピングは氏名（driverName）を第一のキーとする。
  /// ※ 社員番号(employeeNumber)は移行データ等で未入力・仮値のまま入っている
  /// ケースがあり、これをキーにすると本来別人の事故が同一人物として
  /// 誤って集約されてしまう不具合があったため、氏名一致を優先する方式に
  /// 変更した。氏名が空の記録のみ、社員番号があればそれをキーとして扱う。
  /// 氏名・社員番号のいずれも空の記録は個人特定ができないため集計対象から
  /// 除外する。
  ///
  /// ※ ダッシュボード等の「件数」集計と同様に、無責・責任区分不明の事故は
  /// 集計対象から除外する（役員要望に合わせ、有責事故のみを対象とする）。
  ///
  /// [minCount] 以上の事故件数を持つ人物のみを、件数の多い順（同数の場合は
  /// 直近の事故が新しい順）に返す。
  List<RepeatOffender> repeatOffenders({int minCount = 2}) {
    final grouped = <String, List<AccidentRecord>>{};

    for (final r in _records) {
      if (!r.responsibility.isCountable) continue; // 無責・責任区分不明は除外
      final name = r.driverName.trim();
      final empNo = r.employeeNumber.trim();
      if (name.isEmpty && empNo.isEmpty) continue;
      final key = name.isNotEmpty ? 'name:$name' : 'emp:$empNo';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final result = <RepeatOffender>[];
    grouped.forEach((key, records) {
      if (records.length < minCount) return;
      final sorted = [...records]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      // 表示用の氏名・社員番号は、直近(最新)の事故記録の入力内容を優先する
      // (同一人物でも過去の記録に氏名の表記ゆれ等がある場合があるため)。
      final latest = sorted.first;
      result.add(
        RepeatOffender(
          driverName: latest.driverName.trim(),
          employeeNumber: latest.employeeNumber.trim(),
          records: sorted,
        ),
      );
    });

    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return b.records.first.occurredAt.compareTo(a.records.first.occurredAt);
    });
    return result;
  }
}
