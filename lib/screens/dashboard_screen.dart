import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../models/accident_target.dart';
import '../services/accident_service.dart';
import '../services/accident_target_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/accident_list_tile.dart';
import 'accident_detail_screen.dart';
import 'accident_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    return Consumer<AccidentService>(
      builder: (context, service, _) {
        final years = service.availableFiscalYears;
        final currentYear = DateTime.now().month >= 4
            ? DateTime.now().year
            : DateTime.now().year - 1;
        final selectedYear =
            _selectedYear ?? (years.isNotEmpty ? years.first : currentYear);

        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // 集計カード・班別目標進捗に使うのは、集計対象(有責)のもののみ。
        // 一覧表示自体は引き続き全件対象(records)を使用する。
        final records = service.byFiscalYear(selectedYear);
        final excludedCount = service.excludedCount(selectedYear);
        final excludedBreakdown = service.excludedBreakdown(selectedYear);
        final monthly = service.monthlyCountByFiscalYear(selectedYear);
        final charterMonthly =
            service.charterVsOwnMonthlyComparison(selectedYear)[true] ??
            const {};
        final typeBreakdown = service.typeBreakdown(selectedYear);
        // 全社目標(54件)は「自社事故のみ」が基準のため、庸車事故を除いた件数を
        // 別途算出する。庸車事故は目標の対象外のため、参考件数として別枠表示する。
        final ownCompanyCount = service.ownCompanyAccidentCount(selectedYear);
        final charterCount = service.charterAccidentCount(selectedYear);
        // 「原因分析待ち」カードの代わりに表示する、自社有責事故の年度目標。
        // (運用上不要と判断された分析完了系モニターに替えて、会社目標を
        //  一目でわかるようにしたいという要望への対応)
        final companyTarget = context
            .watch<AccidentTargetService>()
            .companyTarget(selectedYear);

        final isDesktop = MediaQuery.of(context).size.width >= 900;

        return RefreshIndicator(
          onRefresh: service.loadRecords,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isDesktop ? 28 : 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildYearSelector(years, currentYear, selectedYear),
                  const SizedBox(height: 16),
                  _buildStatCards(
                    ownCompanyCount,
                    charterCount,
                    companyTarget,
                    selectedYear,
                    isDesktop,
                  ),
                  if (excludedCount > 0) ...[
                    const SizedBox(height: 12),
                    _buildExcludedMonitorCard(excludedCount, excludedBreakdown),
                  ],
                  const SizedBox(height: 24),
                  _buildTargetProgressSection(selectedYear, ownCompanyCount),
                  const SizedBox(height: 24),
                  _sectionTitle('月別事故発生件数'),
                  const SizedBox(height: 12),
                  _buildMonthlyChart(monthly, charterMonthly),
                  const SizedBox(height: 24),
                  _sectionTitle('発生区分の内訳'),
                  const SizedBox(height: 12),
                  _buildTypeBreakdownChart(typeBreakdown),
                  const SizedBox(height: 24),
                  _sectionTitle('直近の事故記録'),
                  const SizedBox(height: 12),
                  ...records
                      .take(5)
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: AccidentListTile(
                            record: r,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccidentDetailScreen(record: r),
                              ),
                            ),
                          ),
                        ),
                      ),
                  if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'この年度の記録はまだありません',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 全社・班別の年度事故目標に対する進捗モニター(件数・パーセンテージ)。
  /// ※全社目標(例:54件)は「自社事故のみ」が基準(庸車事故は含まない)ため、
  ///   ここで渡すcurrentCountは呼び出し側で自社事故のみに絞り込んだ件数を渡す。
  Widget _buildTargetProgressSection(int fiscalYear, int currentCount) {
    return Consumer<AccidentTargetService>(
      builder: (context, targetService, _) {
        if (targetService.isLoading) {
          return const SizedBox();
        }
        final companyTarget = targetService.companyTarget(fiscalYear);
        final teamTargets = targetService.teamTargetsForYear(fiscalYear)
          ..sort((a, b) => a.scope.compareTo(b.scope));

        if (companyTarget == null && teamTargets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$fiscalYear年度の事故目標が未設定です。設定画面(管理者)から登録できます。',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '年度事故目標の進捗',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (companyTarget != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '※全社目標は自社事故のみが対象です（庸車事故は含みません）',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              if (companyTarget != null)
                _targetProgressRow(
                  label: '全社(自社)',
                  current: currentCount,
                  target: companyTarget.targetCount,
                  // 全社目標は特定の班に限定されないため、タップでは
                  // 班フィルタなしの年度のみ絞り込みで一覧を開く。
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccidentListScreen(
                        initialYearFilter: fiscalYear,
                        standalone: true,
                      ),
                    ),
                  ),
                ),
              for (final t in teamTargets)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _targetProgressRow(
                    label: Team.values
                        .firstWhere(
                          (team) => team.name == t.scope,
                          orElse: () => Team.unassigned,
                        )
                        .label,
                    current: context
                        .read<AccidentService>()
                        .countableByFiscalYear(fiscalYear)
                        .where((r) => TargetScope.forTeam(r.team) == t.scope)
                        .length,
                    target: t.targetCount,
                    // 班カードタップで、その班・その年度に絞り込んだ
                    // 事故一覧へ遷移する。
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccidentListScreen(
                          initialYearFilter: fiscalYear,
                          initialTeamFilter: Team.values.firstWhere(
                            (team) => team.name == t.scope,
                            orElse: () => Team.unassigned,
                          ),
                          standalone: true,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 目標進捗の1行。タップすると該当する年度・班に絞り込んだ事故一覧へ遷移する
  /// (現場管理者が該当班の事故内容をすぐに確認できるようにするため)。
  Widget _targetProgressRow({
    required String label,
    required int current,
    required int target,
    VoidCallback? onTap,
  }) {
    if (target <= 0) return const SizedBox();
    final ratio = (current / target).clamp(0.0, 1.5);
    final pct = (current / target * 100);
    Color color;
    if (ratio < 0.7) {
      color = AppColors.success;
    } else if (ratio < 1.0) {
      color = AppColors.warning;
    } else {
      color = AppColors.danger;
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio > 1.0 ? 1.0 : ratio,
                  minHeight: 10,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: Text(
                '$current / $target件',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 90, top: 2),
          child: Text(
            '${pct.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: content,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  // 年度選択チップ。
  // ※以前はChoiceChip(Material標準)を使用していたが、選択時に自動挿入される
  //   チェックマークアイコンと、狭いpadding設定の組み合わせにより、
  //   ラベル文字列の右端(「年度」の「度」)が見切れる不具合があった。
  //   事故一覧のフィルターチップと同様に、幅を内容に合わせて自動調整する
  //   独自Container実装に置き換えることで、見切れを確実に防止する。
  Widget _buildYearSelector(
    List<int> years,
    int currentYear,
    int selectedYear,
  ) {
    final allYears = {...years, currentYear}.toList()
      ..sort((a, b) => b.compareTo(a));
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: allYears.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = allYears[index];
          final selected = year == selectedYear;
          // ※タップ時にInkWellのリップル(波紋)効果で視覚的な反応を
          //   明確にする。GestureDetector単体ではタップの見た目の
          //   フィードバックが全く無く、「反応していない」と誤解されやすい。
          return Material(
            color: selected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() => _selectedYear = year),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected
                        ? AppColors.secondary
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '$year年度',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ダッシュボード上部の統計カード。
  // ※以前は「自社+庸車の合計」「分析完了件数」「分析完了率」の4枚構成だったが、
  //   運用上「事故件数は自社と庸車を分けて見たい」「分析完了系の2枚は不要」との
  //   要望を受け、「自社事故」「庸車事故」「原因分析待ち」の3枚構成に変更した。
  //   その後、「原因分析待ち」は運用上不要と判断されたため、代わりに
  //   自社有責事故の年度目標に対する「残り件数(または超過件数)」を
  //   表示するカードに変更する(会社全体の目標感を一目で把握できるように)。
  Widget _buildStatCards(
    int ownCompanyCount,
    int charterCount,
    AccidentTarget? companyTarget,
    int fiscalYear,
    bool isDesktop,
  ) {
    final cards = [
      StatCard(
        label: '自社事故',
        value: '$ownCompanyCount件',
        icon: Icons.warning_amber_rounded,
        color: AppColors.cardTeal,
      ),
      StatCard(
        label: '庸車事故',
        value: '$charterCount件',
        icon: Icons.local_shipping_outlined,
        color: AppColors.cardPink,
      ),
      _buildTargetRemainingCard(ownCompanyCount, companyTarget, fiscalYear),
    ];
    return GridView.count(
      crossAxisCount: isDesktop ? 3 : 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.5 : 0.95,
      children: cards,
    );
  }

  /// 自社有責事故の年度目標に対する「残り件数」カード。
  /// - 目標未達成: 「目標まであと◯件」(黄〜緑)
  /// - 目標到達/超過: 「目標を◯件超過」(赤)
  /// - 目標未設定: 案内表示のみ
  /// タップすると、その年度の自社事故一覧へ遷移する。
  Widget _buildTargetRemainingCard(
    int ownCompanyCount,
    AccidentTarget? companyTarget,
    int fiscalYear,
  ) {
    String value;
    String label;
    Color color;
    IconData icon;

    if (companyTarget == null || companyTarget.targetCount <= 0) {
      value = '未設定';
      label = '自社事故目標';
      color = AppColors.cardYellow;
      icon = Icons.flag_outlined;
    } else {
      final remaining = companyTarget.targetCount - ownCompanyCount;
      if (remaining > 0) {
        value = 'あと$remaining件';
        label = '自社事故目標(${companyTarget.targetCount}件)まで';
        // 残りが目標の30%を切ったら警戒色にする。
        color = remaining <= companyTarget.targetCount * 0.3
            ? AppColors.danger
            : AppColors.cardYellow;
        icon = Icons.flag_outlined;
      } else if (remaining == 0) {
        value = '目標到達';
        label = '自社事故目標(${companyTarget.targetCount}件)';
        color = AppColors.danger;
        icon = Icons.flag_rounded;
      } else {
        value = '${-remaining}件超過';
        label = '自社事故目標(${companyTarget.targetCount}件)を';
        color = AppColors.danger;
        icon = Icons.flag_rounded;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccidentListScreen(
            initialYearFilter: fiscalYear,
            standalone: true,
          ),
        ),
      ),
      child: StatCard(label: label, value: value, icon: icon, color: color),
    );
  }

  /// 無責・責任区分不明のためカウント対象外になっている件数のモニターカード。
  /// 全体集計・班別集計からは除外されるが、実際に何件あるかを可視化しないと
  /// 「見えない事故」になってしまうため、専用の注記カードとして表示する。
  /// 0件の年度では非表示にし、UIバランスを保つ。
  Widget _buildExcludedMonitorCard(
    int excludedCount,
    Map<Responsibility, int> breakdown,
  ) {
    final noFault = breakdown[Responsibility.noFault] ?? 0;
    final unclear = breakdown[Responsibility.unclear] ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '集計対象外(無責・責任区分不明): $excludedCount件',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '無責 $noFault件 / 責任区分不明 $unclear件（上記の事故件数・班別集計には含まれません）',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 月別事故発生件数の棒グラフ。
  // ※以前はタップ/クリックしないと件数(ツールチップ)が表示されない仕様だった。
  //   常時、件数と庸車件数の内訳を表示してほしいという要望に対応するため、
  //   fl_chartのshowingTooltipIndicatorsを使い、タッチ操作なしで
  //   全バーの上に常時ラベルを表示する方式に変更する。
  Widget _buildMonthlyChart(
    Map<int, int> monthly,
    Map<int, int> charterMonthly,
  ) {
    final months = monthly.keys.toList();
    final maxY =
        (monthly.values.isEmpty
                ? 1
                : monthly.values.reduce((a, b) => a > b ? a : b))
            .toDouble();

    // 1ヶ月あたりに確保する横幅。常時ラベル(件数＋庸車内訳)が隣月と
    // 重ならないよう、バー幅より広めに固定スロット幅を確保する。
    // 画面幅が狭い場合は横スクロールで全12ヶ月分を閲覧できるようにする。
    const slotWidth = 58.0;

    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(8, 40, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth > slotWidth * months.length
              ? constraints.maxWidth
              : slotWidth * months.length;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: chartWidth,
              child: BarChart(
                BarChartData(
                  // 常時ラベル表示のため、上部に余白を多めに確保する。
                  maxY: (maxY < 4 ? 4 : maxY + 1) * 1.35,
                  // タップ操作は不要になったため無効化し、常時表示ラベルのみを使う。
                  barTouchData: BarTouchData(
                    enabled: false,
                    handleBuiltInTouches: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 4,
                      fitInsideVertically: true,
                      fitInsideHorizontally: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = months[groupIndex];
                        final total = monthly[month] ?? 0;
                        if (total == 0) return null;
                        final charter = charterMonthly[month] ?? 0;
                        return BarTooltipItem(
                          '$total件',
                          const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                          children: [
                            TextSpan(
                              text: '\n(庸車$charter件)',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= months.length)
                            return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${months[idx]}月',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: [
                    for (int i = 0; i < months.length; i++)
                      BarChartGroupData(
                        x: i,
                        // 件数が0件の月はラベルを出さず、バーの見た目のみとする。
                        showingTooltipIndicators: (monthly[months[i]] ?? 0) > 0
                            ? [0]
                            : [],
                        barRods: [
                          BarChartRodData(
                            toY: (monthly[months[i]] ?? 0).toDouble(),
                            color: AppColors.primary,
                            width: 14,
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.gradientStart,
                                AppColors.gradientEnd,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeBreakdownChart(Map<AccidentType, int> breakdown) {
    if (breakdown.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'データがありません',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final total = breakdown.values.fold(0, (a, b) => a + b);
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: [
                  for (final e in entries)
                    PieChartSectionData(
                      value: e.value.toDouble(),
                      color: AppColors.forAccidentType(e.key),
                      title: '',
                      radius: 26,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.forAccidentType(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.key.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '${e.value}件 (${total == 0 ? 0 : (e.value / total * 100).round()}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
