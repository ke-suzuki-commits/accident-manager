import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'insight_engine.dart';
import 'report_ai_service.dart';
import 'report_data.dart';

/// 事故分析結果をA3横向きのPDFレポートとして生成するジェネレーター。
///
/// 【ページ構成(役員確定事項)】
/// 1ページ目: サマリー(主要指標・発生区分別・事業所別・班別)
/// 2ページ目: 詳細分析(月別推移※年度モードのみ・前年同月/前年度比較・
///            自社/庸車比較・部品事故要因・常習者分析)
/// 3ページ目: AIによる分析・事故削減への取組み提案
///
/// 【個人情報の扱い】常習者分析の氏名表示のみPDFに含める(AIには渡さない)。
class ReportPdfGenerator {
  // ブランドカラー(app_theme.dartのAppColorsに準拠)。
  static const _primary = PdfColor.fromInt(0xFF00BFA5);
  static const _secondary = PdfColor.fromInt(0xFF7C4DFF);
  static const _textPrimary = PdfColor.fromInt(0xFF1E1E2E);
  static const _textSecondary = PdfColor.fromInt(0xFF5B5E72);
  static const _success = PdfColor.fromInt(0xFF4CAF50);
  static const _warning = PdfColor.fromInt(0xFFFF9800);
  static const _danger = PdfColor.fromInt(0xFFE53935);
  static const _cardYellow = PdfColor.fromInt(0xFFFFB74D);
  static const _background = PdfColor.fromInt(0xFFF7F8FC);

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<void> _ensureFontsLoaded() async {
    if (_regularFont != null && _boldFont != null) return;
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSansJP-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
    _regularFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
  }

  /// PDFバイト列を生成する。
  static Future<List<int>> generate({
    required ReportData data,
    required ReportAiSuggestion aiSuggestion,
  }) async {
    await _ensureFontsLoaded();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _regularFont, bold: _boldFont),
    );

    doc.addPage(_buildSummaryPage(data));
    doc.addPage(_buildDetailPage(data));
    doc.addPage(_buildAiPage(data, aiSuggestion));

    return doc.save();
  }

  // ==================== 1ページ目: サマリー ====================

  static pw.Page _buildSummaryPage(ReportData data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a3.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _reportHeader(data, pageTitle: 'サマリー(1/3)'),
            pw.SizedBox(height: 14),
            _metricCardsRow(data),
            pw.SizedBox(height: 16),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: _breakdownSection(
                      title: '発生区分別件数',
                      data: data.typeBreakdown.map(
                        (k, v) => MapEntry(k.label, v),
                      ),
                      barColor: _primary,
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 1,
                    child: _breakdownSection(
                      title: '発生部署別件数',
                      data: data.officeBreakdown.map(
                        (k, v) => MapEntry(k.label, v),
                      ),
                      barColor: _secondary,
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 1,
                    child: _breakdownSection(
                      title: '班別件数',
                      data: Map.fromEntries(
                        data.teamBreakdown.entries
                            .where((e) => e.value > 0)
                            .map((e) => MapEntry(e.key.label, e.value)),
                      ),
                      barColor: _cardYellow,
                    ),
                  ),
                ],
              ),
            ),
            _reportFooter(data),
          ],
        );
      },
    );
  }

  static pw.Widget _metricCardsRow(ReportData data) {
    final cards = <pw.Widget>[
      _metricCard(
        '集計対象件数(有責)',
        '${data.targetRecords.length}件',
        _primary,
      ),
      _metricCard(
        '集計対象外(無責等)',
        '${data.excludedCount}件',
        _textSecondary,
      ),
      _metricCard(
        '被害金額合計',
        '¥${_fmtNum(data.totalAmount)}',
        _secondary,
      ),
      _metricCard(
        '自社事故 / 庸車事故',
        '${data.ownCompanyCount}件 / ${data.charterCount}件',
        _cardYellow,
      ),
    ];
    if (data.targetCount != null) {
      final pct = data.targetProgressFraction != null
          ? '${(data.targetProgressFraction! * 100).toStringAsFixed(1)}%'
          : '-';
      cards.add(
        _metricCard(
          '年度目標進捗(自社有責)',
          '${data.targetProgressCurrentCount} / ${data.targetCount}件 ($pct)',
          data.targetProgressFraction != null &&
                  data.targetProgressFraction! >
                      InsightEngine.fiscalYearElapsedFraction(
                            data.fiscalYear,
                          ) +
                          0.1
              ? _danger
              : _success,
        ),
      );
    }

    return pw.Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 12),
          pw.Expanded(child: cards[i]),
        ],
      ],
    );
  }

  static pw.Widget _metricCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(_lightenColor(color)),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: color, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 内訳セクション(簡易バーグラフ+数値表)。
  static pw.Widget _breakdownSection({
    required String title,
    required Map<String, int> data,
    required PdfColor barColor,
  }) {
    final entries = data.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          pw.SizedBox(height: 8),
          if (entries.isEmpty)
            pw.Text(
              'データがありません',
              style: pw.TextStyle(fontSize: 9, color: _textSecondary),
            )
          else
            for (final e in entries)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 80,
                      child: pw.Text(
                        e.key,
                        style: pw.TextStyle(fontSize: 8.5, color: _textPrimary),
                        maxLines: 1,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Container(
                        height: 10,
                        decoration: pw.BoxDecoration(
                          color: _background,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: (e.value / maxVal * 1000)
                                  .round()
                                  .clamp(1, 1000),
                              child: pw.Container(
                                height: 10,
                                decoration: pw.BoxDecoration(
                                  color: barColor,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: (1000 -
                                      (e.value / maxVal * 1000).round())
                                  .clamp(0, 999),
                              child: pw.SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.SizedBox(
                      width: 30,
                      child: pw.Text(
                        '${e.value}件',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _textPrimary,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ==================== 2ページ目: 詳細分析 ====================

  static pw.Page _buildDetailPage(ReportData data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a3.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _reportHeader(data, pageTitle: '詳細分析(2/3)'),
            pw.SizedBox(height: 14),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (!data.isMonthMode) ...[
                          _monthlyTrendSection(data),
                          pw.SizedBox(height: 12),
                        ],
                        _yearOverYearSection(data),
                        pw.SizedBox(height: 12),
                        if (data.partsCauseBreakdown.isNotEmpty)
                          pw.Expanded(
                            child: _breakdownSection(
                              title: '部品事故 発生要因別件数',
                              data: data.partsCauseBreakdown.map(
                                (k, v) => MapEntry(k.label, v),
                              ),
                              barColor: _secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(flex: 1, child: _repeatOffendersSection(data)),
                ],
              ),
            ),
            _reportFooter(data),
          ],
        );
      },
    );
  }

  static pw.Widget _monthlyTrendSection(ReportData data) {
    const order = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final maxVal = data.monthlyCount.values.isEmpty
        ? 1
        : data.monthlyCount.values.reduce((a, b) => a > b ? a : b).clamp(
            1,
            999999,
          );
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '月別件数推移(4月〜翌3月)',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (final m in order)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${data.monthlyCount[m] ?? 0}',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          height:
                              38 * (data.monthlyCount[m] ?? 0) / maxVal + 2,
                          decoration: pw.BoxDecoration(
                            color: _primary,
                            borderRadius: const pw.BorderRadius.vertical(
                              top: pw.Radius.circular(2),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text('$m月', style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _yearOverYearSection(ReportData data) {
    final prevLabel = data.isMonthMode ? '前年同月' : '前年度';
    final diff = data.currentPeriodCount - data.previousPeriodCount;
    final diffColor = diff > 0
        ? _danger
        : (diff < 0 ? _success : _textSecondary);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$prevLabel比較',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _smallStatCard('今回', '${data.currentPeriodCount}件', _primary),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _smallStatCard(
                  prevLabel,
                  '${data.previousPeriodCount}件',
                  _textSecondary,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _smallStatCard(
                  '差',
                  diff == 0 ? '±0件' : (diff > 0 ? '+$diff件' : '$diff件'),
                  diffColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _smallStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(_lightenColor(color)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: color)),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _repeatOffendersSection(ReportData data) {
    final offenders = data.repeatOffenders;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '常習者分析(2件以上・全期間累計)',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (offenders.isEmpty)
            pw.Text(
              '現在、2件以上事故を起こしている方はいません',
              style: pw.TextStyle(fontSize: 9, color: _textSecondary),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _background),
                  children: [
                    _tableHeaderCell('氏名'),
                    _tableHeaderCell('役職/立場'),
                    _tableHeaderCell('件数'),
                  ],
                ),
                for (final o in offenders)
                  pw.TableRow(
                    children: [
                      _tableCell(o.name.isEmpty ? '(氏名未入力)' : o.name),
                      _tableCell(o.role.label),
                      _tableCell('${o.count}件'),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  // ==================== 3ページ目: AIによる分析・提案 ====================

  static pw.Page _buildAiPage(ReportData data, ReportAiSuggestion suggestion) {
    return pw.Page(
      pageFormat: PdfPageFormat.a3.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 20),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _reportHeader(data, pageTitle: 'AIによる分析・提案(3/3)'),
            pw.SizedBox(height: 14),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 1, child: _ruleBasedInsightsSection(data)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 1,
                    child: _aiSuggestionSection(suggestion),
                  ),
                ],
              ),
            ),
            _reportFooter(data),
          ],
        );
      },
    );
  }

  static pw.Widget _ruleBasedInsightsSection(ReportData data) {
    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${data.fiscalYear}年度の分析コメント(統計ベース)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          for (final item in data.ruleBasedInsights) _insightBox(item),
        ],
      ),
    );
  }

  static pw.Widget _insightBox(InsightItem item) {
    PdfColor color;
    switch (item.severity) {
      case InsightSeverity.positive:
        color = _success;
        break;
      case InsightSeverity.info:
        color = _secondary;
        break;
      case InsightSeverity.warning:
        color = _warning;
        break;
      case InsightSeverity.danger:
        color = _danger;
        break;
    }
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(_lightenColor(color)),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            item.title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            item.message,
            style: pw.TextStyle(fontSize: 9, color: _textPrimary),
          ),
        ],
      ),
    );
  }

  static pw.Widget _aiSuggestionSection(ReportAiSuggestion suggestion) {
    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_primary, _secondary],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Container(
        width: double.infinity,
        height: double.infinity,
        padding: const pw.EdgeInsets.all(2),
        child: pw.Container(
          width: double.infinity,
          height: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(9),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    '事故削減への取組み提案',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _secondary,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: suggestion.isFallback
                          ? PdfColor.fromInt(_lightenColor(_textSecondary))
                          : PdfColor.fromInt(_lightenColor(_primary)),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      suggestion.isFallback ? '統計ベース分析' : 'AI(Gemini)分析',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: suggestion.isFallback
                            ? _textSecondary
                            : _primary,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                suggestion.summary,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: _textPrimary,
                  lineSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300, height: 1),
              pw.SizedBox(height: 10),
              for (int i = 0; i < suggestion.proposals.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 16,
                        height: 16,
                        decoration: const pw.BoxDecoration(
                          color: _secondary,
                          shape: pw.BoxShape.circle,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          '${i + 1}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Expanded(
                        child: pw.Text(
                          suggestion.proposals[i],
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            color: _textPrimary,
                            lineSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 共通ヘッダー・フッター ====================

  static pw.Widget _reportHeader(ReportData data, {required String pageTitle}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_primary, _secondary],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '事故分析レポート',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '対象期間: ${data.periodLabel}(全事業所・全班)',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
            ],
          ),
          pw.Text(
            pageTitle,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _reportFooter(ReportData data) {
    final generated =
        '${data.generatedAt.year}/${data.generatedAt.month.toString().padLeft(2, '0')}/'
        '${data.generatedAt.day.toString().padLeft(2, '0')} '
        '${data.generatedAt.hour.toString().padLeft(2, '0')}:'
        '${data.generatedAt.minute.toString().padLeft(2, '0')}';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '出力日時: $generated',
            style: pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
          pw.Text(
            '事故対応管理アプリ 自動生成レポート(設定画面の内容は含みません)',
            style: pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  static String _fmtNum(double v) {
    return v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  /// 指定色を白と混ぜて明るくした色(背景用の淡色)を返す。
  static int _lightenColor(PdfColor color) {
    const factor = 0.88;
    final r = (color.red * 255).round();
    final g = (color.green * 255).round();
    final b = (color.blue * 255).round();
    final lr = (r + (255 - r) * factor).round().clamp(0, 255);
    final lg = (g + (255 - g) * factor).round().clamp(0, 255);
    final lb = (b + (255 - b) * factor).round().clamp(0, 255);
    return 0xFF000000 | (lr << 16) | (lg << 8) | lb;
  }
}
