import '../models/accident_master.dart';
import '../models/accident_record.dart';
import 'accident_service.dart';
import 'accident_target_service.dart';
import 'insight_engine.dart';

/// PDF分析レポートの対象モード。
enum ReportMode { month, fiscalYear }

/// PDF分析レポート1件分を生成するために必要な、集計済みの統計データ一式。
///
/// 【重要】個人情報保護の観点から、氏名・社員番号等の個人を特定できる情報は
/// このクラスには一切含めない(常習者分析のみ例外的に氏名を保持するが、
/// これはAIには渡さずPDF内の単純な表としてのみ使用する)。
/// Geminiへの提案生成リクエストは、このクラスの`toAiPromptSummary()`が返す
/// 統計値のみを渡すことで、個人情報の外部送信を防ぐ設計とする。
class ReportData {
  final ReportMode mode;
  final int fiscalYear;
  final int? month; // モード=monthの場合のみ有効(fiscalMonth: 1-12)
  final DateTime generatedAt;

  // ---- 対象期間の事故記録(全社・全班) ----
  final List<AccidentRecord> targetRecords; // 集計対象(有責)のみ
  final int excludedCount; // 無責・責任区分不明の件数(参考情報)

  // ---- サマリー ----
  final double totalAmount;

  // ---- 内訳 ----
  final Map<AccidentType, int> typeBreakdown;
  final Map<OfficeDept, int> officeBreakdown;
  final Map<Team, int> teamBreakdown;
  final Map<PartsAccidentCause, int> partsCauseBreakdown;

  // ---- 月別推移(年度モードのみ意味を持つ。単月モードでは空) ----
  final Map<int, int> monthlyCount; // 4月->3月の順

  // ---- 前年同月/前年度比較 ----
  final int previousPeriodCount; // 単月:前年同月件数 / 年度:前年度累計件数
  final int currentPeriodCount; // 単月:当月件数 / 年度:当年度累計件数

  // ---- 自社/庸車比較 ----
  final int charterCount;
  final int ownCompanyCount;

  // ---- 年度目標進捗(単月モードでもその月末時点までの年度累計実績で算出) ----
  final int? targetCount; // 全社目標(未設定ならnull)
  final int targetProgressCurrentCount; // 目標算出基準の累計件数
  final double? targetProgressFraction; // currentCount / targetCount

  // ---- AIによる分析(ルールベース、既存のInsightEngineの結果) ----
  final List<InsightItem> ruleBasedInsights;

  // ---- 常習者分析(氏名を含む。AIには渡さずPDF内の単純表としてのみ使用) ----
  final List<RepeatOffender> repeatOffenders;

  const ReportData({
    required this.mode,
    required this.fiscalYear,
    this.month,
    required this.generatedAt,
    required this.targetRecords,
    required this.excludedCount,
    required this.totalAmount,
    required this.typeBreakdown,
    required this.officeBreakdown,
    required this.teamBreakdown,
    required this.partsCauseBreakdown,
    required this.monthlyCount,
    required this.previousPeriodCount,
    required this.currentPeriodCount,
    required this.charterCount,
    required this.ownCompanyCount,
    required this.targetCount,
    required this.targetProgressCurrentCount,
    required this.targetProgressFraction,
    required this.ruleBasedInsights,
    required this.repeatOffenders,
  });

  bool get isMonthMode => mode == ReportMode.month;

  /// 期間の表示ラベル(例: 「2026年度 6月」「2026年度(4月〜翌3月)」)
  String get periodLabel {
    if (isMonthMode) {
      return '$fiscalYear年度 $month月';
    }
    return '$fiscalYear年度(4月〜翌3月)';
  }

  /// Geminiへ渡す、個人情報を含まない統計サマリー文字列を構築する。
  /// 【個人情報保護】氏名・社員番号等は一切含めない。件数・比率等の
  /// 集計済み数値データのみで構成する。
  String toAiPromptSummary() {
    final buf = StringBuffer();
    buf.writeln('【対象期間】$periodLabel');
    buf.writeln('【集計対象件数(有責のみ)】${targetRecords.length}件');
    buf.writeln('【被害金額合計】¥${totalAmount.toStringAsFixed(0)}');
    buf.writeln();

    buf.writeln('【発生区分別件数】');
    final sortedTypes = typeBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedTypes) {
      if (e.value == 0) continue;
      buf.writeln('- ${e.key.label}: ${e.value}件');
    }
    buf.writeln();

    if (partsCauseBreakdown.isNotEmpty) {
      buf.writeln('【部品事故の発生要因別件数】');
      final sortedCauses = partsCauseBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sortedCauses) {
        buf.writeln('- ${e.key.label}: ${e.value}件');
      }
      buf.writeln();
    }

    buf.writeln('【発生部署別件数】');
    final sortedOffices = officeBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedOffices) {
      if (e.value == 0) continue;
      buf.writeln('- ${e.key.label}: ${e.value}件');
    }
    buf.writeln();

    buf.writeln('【班別件数】');
    final sortedTeams = teamBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedTeams) {
      if (e.value == 0) continue;
      buf.writeln('- ${e.key.label}: ${e.value}件');
    }
    buf.writeln();

    buf.writeln('【自社事故/庸車事故】');
    buf.writeln('- 自社事故: $ownCompanyCount件');
    buf.writeln('- 庸車事故: $charterCount件');
    buf.writeln();

    if (!isMonthMode && monthlyCount.isNotEmpty) {
      buf.writeln('【月別件数推移(4月〜翌3月)】');
      const order = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
      for (final m in order) {
        buf.writeln('- $m月: ${monthlyCount[m] ?? 0}件');
      }
      buf.writeln();
    }

    final prevLabel = isMonthMode ? '前年同月' : '前年度';
    buf.writeln('【$prevLabel比較】');
    buf.writeln('- 今回: $currentPeriodCount件');
    buf.writeln('- $prevLabel: $previousPeriodCount件');
    buf.writeln();

    if (targetCount != null) {
      buf.writeln('【年度目標に対する進捗】');
      buf.writeln('- 全社目標: $targetCount件');
      buf.writeln('- 現在までの累計実績: $targetProgressCurrentCount件');
      if (targetProgressFraction != null) {
        buf.writeln(
          '- 進捗率: ${(targetProgressFraction! * 100).toStringAsFixed(1)}%',
        );
      }
      buf.writeln();
    }

    if (excludedCount > 0) {
      buf.writeln('【参考】無責・責任区分不明のため上記集計対象外: $excludedCount件');
    }

    return buf.toString();
  }
}

/// [ReportData]を構築するビルダー。
/// AccidentService/AccidentTargetServiceの既存集計メソッドを組み合わせて
/// 単月・年度いずれのモードでも共通のデータ構造を組み立てる。
class ReportDataBuilder {
  static ReportData build({
    required AccidentService accidentService,
    required AccidentTargetService targetService,
    required ReportMode mode,
    required int fiscalYear,
    int? month,
  }) {
    final allInYear = accidentService.byFiscalYear(fiscalYear);
    final countableInYear = accidentService.countableByFiscalYear(fiscalYear);

    // 対象期間(単月 or 年度)に絞った有責記録。
    final targetRecords = mode == ReportMode.month
        ? countableInYear.where((r) => r.fiscalMonth == month).toList()
        : countableInYear;

    // 集計対象外(無責・責任区分不明)の件数。
    final excludedCount = mode == ReportMode.month
        ? allInYear
              .where(
                (r) =>
                    r.fiscalMonth == month && !r.responsibility.isCountable,
              )
              .length
        : accidentService.excludedCount(fiscalYear);

    // 被害金額合計(単月モードは対象月のみ、年度モードは年度全体)。
    final totalAmount = mode == ReportMode.month
        ? allInYear
              .where((r) => r.fiscalMonth == month)
              .fold(
                0.0,
                (sum, r) => sum + r.compensationAmount + r.processingCost,
              )
        : accidentService.totalAmount(fiscalYear);

    // 内訳(発生区分・部署・班・部品事故要因)は対象期間の記録から直接集計する。
    final typeBreakdown = <AccidentType, int>{};
    final officeBreakdown = <OfficeDept, int>{};
    final teamBreakdown = <Team, int>{};
    final partsCauseBreakdown = <PartsAccidentCause, int>{};
    for (final r in targetRecords) {
      typeBreakdown[r.accidentType] = (typeBreakdown[r.accidentType] ?? 0) + 1;
      officeBreakdown[r.office] = (officeBreakdown[r.office] ?? 0) + 1;
      teamBreakdown[r.team] = (teamBreakdown[r.team] ?? 0) + 1;
      if (r.partsCause != null) {
        partsCauseBreakdown[r.partsCause!] =
            (partsCauseBreakdown[r.partsCause!] ?? 0) + 1;
      }
    }

    // 月別推移(年度モードのみ)。
    final monthlyCount = mode == ReportMode.fiscalYear
        ? accidentService.monthlyCountByFiscalYear(fiscalYear)
        : <int, int>{};

    // 前年同月/前年度比較。
    int previousPeriodCount;
    int currentPeriodCount;
    if (mode == ReportMode.month) {
      final cmp = accidentService.sameMonthYearOverYear(fiscalYear, month!);
      currentPeriodCount = cmp.current;
      previousPeriodCount = cmp.previous;
    } else {
      currentPeriodCount = countableInYear.length;
      previousPeriodCount = accidentService
          .countableByFiscalYear(fiscalYear - 1)
          .length;
    }

    // 自社/庸車比較(対象期間のみ)。
    final charterCount = targetRecords.where((r) => r.office.isCharter).length;
    final ownCompanyCount = targetRecords.length - charterCount;

    // 年度目標進捗。単月モードでも「その月末時点までの年度累計実績」で算出する
    // (ユーザー確定事項: 案1)。
    final target = targetService.companyTarget(fiscalYear);
    int targetProgressCurrentCount;
    if (mode == ReportMode.month) {
      // 4月からmonthまで(fiscalMonth基準)の年度累計(自社有責のみ、既存の
      // 目標進捗insightと算出基準を揃える)。
      targetProgressCurrentCount = countableInYear
          .where((r) => !r.office.isCharter)
          .where((r) => _isWithinFiscalRange(r.fiscalMonth, month!))
          .length;
    } else {
      targetProgressCurrentCount = accidentService.ownCompanyAccidentCount(
        fiscalYear,
      );
    }
    final targetCount = target?.targetCount;
    final targetProgressFraction =
        (targetCount != null && targetCount > 0)
        ? targetProgressCurrentCount / targetCount
        : null;

    // AIによる分析(ルールベース、既存のInsightEngine)。
    final ruleBasedInsights = InsightEngine.analyze(
      accidentService: accidentService,
      targetService: targetService,
      fiscalYear: fiscalYear,
    );

    // 常習者分析(全期間累計。既存のrepeatOffenders()をそのまま利用)。
    final repeatOffenders = accidentService.repeatOffenders();

    return ReportData(
      mode: mode,
      fiscalYear: fiscalYear,
      month: month,
      generatedAt: DateTime.now(),
      targetRecords: targetRecords,
      excludedCount: excludedCount,
      totalAmount: totalAmount,
      typeBreakdown: typeBreakdown,
      officeBreakdown: officeBreakdown,
      teamBreakdown: teamBreakdown,
      partsCauseBreakdown: partsCauseBreakdown,
      monthlyCount: monthlyCount,
      previousPeriodCount: previousPeriodCount,
      currentPeriodCount: currentPeriodCount,
      charterCount: charterCount,
      ownCompanyCount: ownCompanyCount,
      targetCount: targetCount,
      targetProgressCurrentCount: targetProgressCurrentCount,
      targetProgressFraction: targetProgressFraction,
      ruleBasedInsights: ruleBasedInsights,
      repeatOffenders: repeatOffenders,
    );
  }

  /// 年度(4月始まり)基準で、fiscalMonthが4月から[uptoMonth]までの範囲内かどうか。
  /// 例: uptoMonth=6(6月) -> 4,5,6月がtrue。uptoMonth=1(1月) -> 4〜12,1月がtrue。
  static bool _isWithinFiscalRange(int fiscalMonth, int uptoMonth) {
    const order = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final uptoIndex = order.indexOf(uptoMonth);
    final targetIndex = order.indexOf(fiscalMonth);
    return targetIndex <= uptoIndex;
  }
}
