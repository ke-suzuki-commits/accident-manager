import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../services/accident_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/accident_list_tile.dart';
import 'accident_detail_screen.dart';

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

        final records = service.byFiscalYear(selectedYear);
        final monthly = service.monthlyCountByFiscalYear(selectedYear);
        final uncompleted = service.uncompletedAnalysisCount(selectedYear);
        final analyzed = service.analyzedCount(selectedYear);
        final typeBreakdown = service.typeBreakdown(selectedYear);

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
                    records.length,
                    uncompleted,
                    analyzed,
                    isDesktop,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('月別事故発生件数'),
                  const SizedBox(height: 12),
                  _buildMonthlyChart(monthly),
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
                        color: selected
                            ? Colors.white
                            : AppColors.textPrimary,
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

  Widget _buildStatCards(
    int total,
    int uncompleted,
    int analyzed,
    bool isDesktop,
  ) {
    final cards = [
      StatCard(
        label: '事故件数',
        value: '$total件',
        icon: Icons.warning_amber_rounded,
        color: AppColors.cardTeal,
      ),
      StatCard(
        label: '原因分析待ち',
        value: '$uncompleted件',
        icon: Icons.psychology_alt_rounded,
        color: AppColors.cardYellow,
      ),
      StatCard(
        label: '分析完了',
        value: '$analyzed件',
        icon: Icons.verified_rounded,
        color: AppColors.cardPurple,
      ),
      StatCard(
        label: '分析完了率',
        value: total == 0
            ? '-'
            : '${(((total - uncompleted) / total) * 100).round()}%',
        icon: Icons.trending_up_rounded,
        color: AppColors.cardPink,
      ),
    ];
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.3 : 1.15,
      children: cards,
    );
  }

  Widget _buildMonthlyChart(Map<int, int> monthly) {
    final months = monthly.keys.toList();
    final maxY =
        (monthly.values.isEmpty
                ? 1
                : monthly.values.reduce((a, b) => a > b ? a : b))
            .toDouble();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY < 4 ? 4 : maxY + 1,
          barTouchData: BarTouchData(enabled: true),
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
                  if (idx < 0 || idx >= months.length) return const SizedBox();
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
                barRods: [
                  BarChartRodData(
                    toY: (monthly[months[i]] ?? 0).toDouble(),
                    color: AppColors.primary,
                    width: 14,
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              ),
          ],
        ),
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
