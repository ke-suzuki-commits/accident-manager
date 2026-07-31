import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../services/accident_service.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final Set<int> _selectedYears = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AccidentService>(
      builder: (context, service, _) {
        final years = service.availableFiscalYears;
        if (_selectedYears.isEmpty && years.isNotEmpty) {
          _selectedYears.addAll(years.take(2));
        }
        final isDesktop = MediaQuery.of(context).size.width >= 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 28 : 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '傾向分析・年度比較',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '複数年度を選択して月別トレンドを比較できます',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                _buildYearMultiSelect(years),
                const SizedBox(height: 24),
                _sectionTitle('年度別 月次推移比較'),
                const SizedBox(height: 12),
                _buildComparisonChart(service),
                const SizedBox(height: 24),
                _sectionTitle('年度別 総件数・被害額'),
                const SizedBox(height: 12),
                _buildYearSummaryTable(service, years),
                const SizedBox(height: 24),
                _sectionTitle('発生部署別 件数比較'),
                const SizedBox(height: 12),
                _buildOfficeComparisonChart(service),
                const SizedBox(height: 24),
                _sectionTitle('庸車事故 / 自社事故 比較'),
                const SizedBox(height: 12),
                _buildCharterVsOwnSummary(service),
                const SizedBox(height: 24),
                _sectionTitle('班別 件数集計'),
                const SizedBox(height: 12),
                _buildTeamBreakdownChart(service),
                const SizedBox(height: 24),
                _sectionTitle('部品事故 発生要因ランキング'),
                const SizedBox(height: 12),
                _buildPartsCauseRanking(service),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );

  Widget _buildYearMultiSelect(List<int> years) {
    return Wrap(
      spacing: 8,
      children: [
        for (final y in years)
          FilterChip(
            label: Text('$y年度'),
            selected: _selectedYears.contains(y),
            selectedColor: AppColors.secondary,
            labelStyle: TextStyle(
              color: _selectedYears.contains(y)
                  ? Colors.white
                  : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            backgroundColor: Colors.white,
            onSelected: (v) => setState(() {
              if (v) {
                _selectedYears.add(y);
              } else {
                _selectedYears.remove(y);
              }
            }),
          ),
      ],
    );
  }

  static const _yearColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.cardPink,
    AppColors.cardYellow,
  ];

  Widget _buildComparisonChart(AccidentService service) {
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final selectedYearsList = _selectedYears.toList()..sort();

    // データが無い状態でLineChartに空のlineBarsDataを渡すと、
    // fl_chartの内部レイアウト処理でnull-check例外が発生することがある。
    // (IndexedStackで本画面が非表示でも常時ビルドされるため、
    //  他タブの表示にまで影響する重大な不具合の原因だった)
    if (selectedYearsList.isEmpty) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '比較する年度を選択してください',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final data = service.multiYearMonthlyComparison(selectedYearsList);

    double maxY = 4;
    for (final m in data.values) {
      for (final v in m.values) {
        if (v.toDouble() > maxY) maxY = v.toDouble();
      }
    }

    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 16,
            children: [
              for (int i = 0; i < selectedYearsList.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: _yearColors[i % _yearColors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${selectedYearsList[i]}年度',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                maxY: maxY + 1,
                minY: 0,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) {
                          return const SizedBox();
                        }
                        return Text(
                          '${months[idx]}月',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  for (int i = 0; i < selectedYearsList.length; i++)
                    LineChartBarData(
                      isCurved: true,
                      color: _yearColors[i % _yearColors.length],
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      spots: [
                        for (int j = 0; j < months.length; j++)
                          FlSpot(
                            j.toDouble(),
                            (data[selectedYearsList[i]]?[months[j]] ?? 0)
                                .toDouble(),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSummaryTable(AccidentService service, List<int> years) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.5),
        },
        children: [
          const TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '年度',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '件数',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '金額合計',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          for (final y in years)
            TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('$y年度')),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${service.byFiscalYear(y).length}件'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('¥${service.totalAmount(y).toStringAsFixed(0)}'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOfficeComparisonChart(AccidentService service) {
    final selectedYearsList = _selectedYears.toList()..sort();
    if (selectedYearsList.isEmpty) return const SizedBox();

    final allOffices = OfficeDept.values;
    double maxY = 4;
    final dataByYear = <int, Map<OfficeDept, int>>{};
    for (final y in selectedYearsList) {
      final b = service.officeBreakdown(y);
      dataByYear[y] = b;
      for (final v in b.values) {
        if (v.toDouble() > maxY) maxY = v.toDouble();
      }
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
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
                  if (idx < 0 || idx >= allOffices.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      allOffices[idx].label,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < allOffices.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  for (int j = 0; j < selectedYearsList.length; j++)
                    BarChartRodData(
                      toY:
                          (dataByYear[selectedYearsList[j]]?[allOffices[i]] ??
                                  0)
                              .toDouble(),
                      color: _yearColors[j % _yearColors.length],
                      width: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 庸車事故（発生部署＝傭車）と自社事故を分けて件数比較するサマリーカード。
  /// 役員要望②「庸車事故と自社での事故は分けて集計」に対応。
  Widget _buildCharterVsOwnSummary(AccidentService service) {
    final selectedYearsList = _selectedYears.toList()..sort();
    if (selectedYearsList.isEmpty) return const SizedBox();

    int charterTotal = 0;
    int ownTotal = 0;
    for (final y in selectedYearsList) {
      charterTotal += service.charterAccidentCount(y);
      ownTotal += service.ownCompanyAccidentCount(y);
    }
    final total = charterTotal + ownTotal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _charterOwnCard(
                  label: '庸車事故',
                  count: charterTotal,
                  total: total,
                  color: AppColors.cardYellow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _charterOwnCard(
                  label: '自社事故',
                  count: ownTotal,
                  total: total,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCharterVsOwnMonthlyChart(service, selectedYearsList),
        ],
      ),
    );
  }

  Widget _charterOwnCard({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final pct = total == 0 ? 0 : (count / total * 100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count件',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '全体の${pct.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 選択年度をまとめた庸車/自社の月別件数推移（積み上げ表現ではなく単純比較）
  Widget _buildCharterVsOwnMonthlyChart(
    AccidentService service,
    List<int> selectedYearsList,
  ) {
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final charterMonthly = {for (final m in months) m: 0};
    final ownMonthly = {for (final m in months) m: 0};
    for (final y in selectedYearsList) {
      final cmp = service.charterVsOwnMonthlyComparison(y);
      for (final m in months) {
        charterMonthly[m] = charterMonthly[m]! + (cmp[true]?[m] ?? 0);
        ownMonthly[m] = ownMonthly[m]! + (cmp[false]?[m] ?? 0);
      }
    }
    double maxY = 4;
    for (final m in months) {
      if (charterMonthly[m]!.toDouble() > maxY) maxY = charterMonthly[m]!.toDouble();
      if (ownMonthly[m]!.toDouble() > maxY) maxY = ownMonthly[m]!.toDouble();
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
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
                  if (idx < 0 || idx >= months.length) {
                    return const SizedBox();
                  }
                  return Text(
                    '${months[idx]}月',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < months.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: charterMonthly[months[i]]!.toDouble(),
                    color: AppColors.cardYellow,
                    width: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  BarChartRodData(
                    toY: ownMonthly[months[i]]!.toDouble(),
                    color: AppColors.secondary,
                    width: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// 班別（A班〜O班）の件数集計。役員要望①に対応。
  Widget _buildTeamBreakdownChart(AccidentService service) {
    final selectedYearsList = _selectedYears.toList()..sort();
    if (selectedYearsList.isEmpty) return const SizedBox();

    final merged = <Team, int>{};
    for (final y in selectedYearsList) {
      service.teamBreakdown(y).forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    }
    // 「未設定」は班未入力の過去データ用。集計上は表示するが末尾に回す。
    final teams = Team.values.where((t) => t != Team.unassigned).toList();
    final unassignedCount = merged[Team.unassigned] ?? 0;

    double maxY = 4;
    for (final t in teams) {
      final v = (merged[t] ?? 0).toDouble();
      if (v > maxY) maxY = v;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY + 1,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
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
                        if (idx < 0 || idx >= teams.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            teams[idx].label,
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
                barGroups: [
                  for (int i = 0; i < teams.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (merged[teams[i]] ?? 0).toDouble(),
                          gradient: AppColors.headerGradient,
                          width: 14,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (unassignedCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '※班未設定のデータ: $unassignedCount件（Excel移行データ等）',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartsCauseRanking(AccidentService service) {
    final selectedYearsList = _selectedYears.toList()..sort();
    final merged = <PartsAccidentCause, int>{};
    for (final y in selectedYearsList) {
      service
          .partsCauseBreakdown(y)
          .forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    }
    final entries = merged.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '部品事故のデータがありません',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final maxVal = entries.first.value;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      e.key.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: e.value / maxVal,
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              gradient: AppColors.headerGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.value}件',
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
    );
  }
}
