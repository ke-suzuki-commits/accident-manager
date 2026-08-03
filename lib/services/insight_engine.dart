import '../models/accident_master.dart';
import 'accident_service.dart';
import 'accident_target_service.dart';

enum InsightSeverity { positive, info, warning, danger }

class InsightItem {
  final String title;
  final String message;
  final InsightSeverity severity;

  const InsightItem({
    required this.title,
    required this.message,
    required this.severity,
  });
}

/// 統計ベースの傾向分析エンジン(「AIによる分析」機能)。
///
/// 生成AI(LLM)を使わず、蓄積された事故データを集計・比較して
/// ルールベースで気づきを日本語の文章として生成する。
/// 外部APIキーや追加費用が不要で、オフラインでも即時に動作する。
class InsightEngine {
  static List<InsightItem> analyze({
    required AccidentService accidentService,
    required AccidentTargetService targetService,
    required int fiscalYear,
  }) {
    final insights = <InsightItem>[];
    final current = accidentService.byFiscalYear(fiscalYear);
    final previous = accidentService.byFiscalYear(fiscalYear - 1);

    _addYearOverYearInsight(
      insights,
      fiscalYear,
      current.length,
      previous.length,
    );
    _addSameMonthInsight(insights, accidentService, fiscalYear);
    _addTeamInsight(insights, accidentService, fiscalYear);
    _addTypeInsight(insights, accidentService, fiscalYear);
    _addCharterInsight(insights, accidentService, fiscalYear);
    _addTargetProgressInsight(
      insights,
      accidentService,
      targetService,
      fiscalYear,
    );
    _addCostInsight(insights, accidentService, fiscalYear);

    if (insights.isEmpty) {
      insights.add(
        const InsightItem(
          title: '分析データが不足しています',
          message: '事故記録が蓄積されると、傾向分析・目標進捗などの気づきがここに表示されます。',
          severity: InsightSeverity.info,
        ),
      );
    }
    return insights;
  }

  static void _addYearOverYearInsight(
    List<InsightItem> insights,
    int fiscalYear,
    int currentCount,
    int previousCount,
  ) {
    if (previousCount == 0) return;
    final diff = currentCount - previousCount;
    final pct = (diff / previousCount * 100);
    if (diff > 0) {
      insights.add(
        InsightItem(
          title: '前年度比:増加傾向',
          message:
              '$fiscalYear年度の累計事故件数は$currentCount件で、前年度($previousCount件)より'
              '$diff件(+${pct.toStringAsFixed(1)}%)増加しています。要因分析と対策強化を検討してください。',
          severity: InsightSeverity.warning,
        ),
      );
    } else if (diff < 0) {
      insights.add(
        InsightItem(
          title: '前年度比:改善傾向',
          message:
              '$fiscalYear年度の累計事故件数は$currentCount件で、前年度($previousCount件)より'
              '${-diff}件(${pct.toStringAsFixed(1)}%)減少しています。取り組みの成果が出ています。',
          severity: InsightSeverity.positive,
        ),
      );
    }
  }

  static void _addSameMonthInsight(
    List<InsightItem> insights,
    AccidentService service,
    int fiscalYear,
  ) {
    final now = DateTime.now();
    final targetMonth = now.month;
    final thisMonth = service
        .byFiscalYear(fiscalYear)
        .where((r) => r.fiscalMonth == targetMonth)
        .length;
    final lastYearSameMonth = service
        .byFiscalYear(fiscalYear - 1)
        .where((r) => r.fiscalMonth == targetMonth)
        .length;
    if (thisMonth == 0 && lastYearSameMonth == 0) return;
    final diff = thisMonth - lastYearSameMonth;
    if (diff > 0) {
      insights.add(
        InsightItem(
          title: '今月は前年同月より増加',
          message:
              '$targetMonth月の事故件数は現時点で$thisMonth件。前年度同月($lastYearSameMonth件)より'
              '$diff件多いペースです。月内の注意喚起を検討してください。',
          severity: InsightSeverity.warning,
        ),
      );
    } else if (diff < 0) {
      insights.add(
        InsightItem(
          title: '今月は前年同月より改善',
          message:
              '$targetMonth月の事故件数は現時点で$thisMonth件。前年度同月($lastYearSameMonth件)より'
              '${-diff}件少ないペースです。',
          severity: InsightSeverity.positive,
        ),
      );
    } else {
      insights.add(
        InsightItem(
          title: '今月は前年同月と同水準',
          message: '$targetMonth月の事故件数は現時点で$thisMonth件。前年度同月と同じ件数です。',
          severity: InsightSeverity.info,
        ),
      );
    }
  }

  static void _addTeamInsight(
    List<InsightItem> insights,
    AccidentService service,
    int fiscalYear,
  ) {
    final breakdown = Map<Team, int>.from(service.teamBreakdown(fiscalYear))
      ..removeWhere((k, v) => k == Team.unassigned || v == 0);
    if (breakdown.isEmpty) return;
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    if (top.value >= 2) {
      insights.add(
        InsightItem(
          title: '多発している班',
          message:
              '${top.key.label}の事故件数が$fiscalYear年度累計で${top.value}件と最多です。'
              '班内での注意喚起・安全教育の強化を検討してください。',
          severity: InsightSeverity.warning,
        ),
      );
    }
  }

  static void _addTypeInsight(
    List<InsightItem> insights,
    AccidentService service,
    int fiscalYear,
  ) {
    final breakdown = service.typeBreakdown(fiscalYear);
    if (breakdown.isEmpty) return;
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    insights.add(
      InsightItem(
        title: '最も多い発生区分',
        message: '「${top.key.label}」が$fiscalYear年度累計${top.value}件と最も多く発生しています。',
        severity: InsightSeverity.info,
      ),
    );
  }

  static void _addCharterInsight(
    List<InsightItem> insights,
    AccidentService service,
    int fiscalYear,
  ) {
    final charter = service.charterAccidentCount(fiscalYear);
    final own = service.ownCompanyAccidentCount(fiscalYear);
    final total = charter + own;
    if (total == 0) return;
    final charterPct = charter / total * 100;
    if (charterPct >= 40) {
      insights.add(
        InsightItem(
          title: '庸車事故の比率が高め',
          message:
              '$fiscalYear年度は庸車事故が$charter件(全体の${charterPct.toStringAsFixed(1)}%)を'
              '占めています。委託先への安全指導の強化を検討してください。',
          severity: InsightSeverity.warning,
        ),
      );
    }
  }

  static void _addTargetProgressInsight(
    List<InsightItem> insights,
    AccidentService accidentService,
    AccidentTargetService targetService,
    int fiscalYear,
  ) {
    final target = targetService.companyTarget(fiscalYear);
    if (target == null || target.targetCount <= 0) return;
    final currentCount = accidentService.byFiscalYear(fiscalYear).length;
    final progress = currentCount / target.targetCount;
    final elapsed = fiscalYearElapsedFraction(fiscalYear);
    if (elapsed <= 0) return;
    if (progress > elapsed + 0.1) {
      insights.add(
        InsightItem(
          title: '全社目標:ペースが早いおそれ',
          message:
              '全社目標${target.targetCount}件に対し、既に$currentCount件'
              '(${(progress * 100).toStringAsFixed(1)}%)発生しています。'
              '年度の経過(${(elapsed * 100).toStringAsFixed(0)}%)に対して発生ペースが速く、'
              'このままでは目標超過のおそれがあります。',
          severity: InsightSeverity.danger,
        ),
      );
    } else {
      insights.add(
        InsightItem(
          title: '全社目標:順調なペース',
          message:
              '全社目標${target.targetCount}件に対し、現在$currentCount件'
              '(${(progress * 100).toStringAsFixed(1)}%)。'
              '年度の経過(${(elapsed * 100).toStringAsFixed(0)}%)に対して概ね順調なペースです。',
          severity: InsightSeverity.positive,
        ),
      );
    }
  }

  static void _addCostInsight(
    List<InsightItem> insights,
    AccidentService service,
    int fiscalYear,
  ) {
    final total = service.totalAmount(fiscalYear);
    if (total <= 0) return;
    insights.add(
      InsightItem(
        title: '費用への影響',
        message: '$fiscalYear年度の賠償金額・事故処理諸費用の合計は¥${_fmt(total)}です。',
        severity: InsightSeverity.info,
      ),
    );
  }

  /// 年度(4月始まり)の経過割合(0.0〜1.0)。
  static double fiscalYearElapsedFraction(int fiscalYear) {
    final start = DateTime(fiscalYear, 4, 1);
    final end = DateTime(fiscalYear + 1, 4, 1);
    final now = DateTime.now();
    if (now.isBefore(start)) return 0;
    if (!now.isBefore(end)) return 1;
    return now.difference(start).inMilliseconds /
        end.difference(start).inMilliseconds;
  }

  static String _fmt(double v) {
    return v
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
