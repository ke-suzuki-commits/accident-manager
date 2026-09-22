import 'dart:convert';
import 'package:http/http.dart' as http;
import 'report_data.dart';

/// Geminiによる「事故削減への取組み提案」生成結果。
class ReportAiSuggestion {
  final String summary; // 多角的な分析結果の要約
  final List<String> proposals; // 取組み提案(3〜5件程度)
  final bool isFallback; // AI呼び出し失敗時のルールベース代替文かどうか

  const ReportAiSuggestion({
    required this.summary,
    required this.proposals,
    this.isFallback = false,
  });

  factory ReportAiSuggestion.fromJson(Map<String, dynamic> json) {
    return ReportAiSuggestion(
      summary: json['summary']?.toString() ?? '',
      proposals:
          (json['proposals'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

/// PDF分析レポート用「事故削減への取組み提案」をGemini APIで生成するサービス。
///
/// 【個人情報保護】[ReportData.toAiPromptSummary]が返す統計サマリー(件数・比率等の
/// 集計済み数値のみ)のみをプロンプトに含める。氏名・社員番号等の個人情報は
/// 一切送信しない(常習者分析はAI処理対象外とし、PDF内の単純な表としてのみ使用)。
///
/// 【フォールバック】通信エラー・APIキー未設定・応答解析失敗など、いずれの
/// 理由でもAI呼び出しに失敗した場合は、既存のルールベース分析結果
/// ([ReportData.ruleBasedInsights])から簡易な代替提案文を生成し、
/// PDF生成自体が失敗しないようにする。
class ReportAiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  Future<ReportAiSuggestion> generateSuggestion({
    required String apiKey,
    required ReportData data,
  }) async {
    if (apiKey.isEmpty) {
      return _fallback(data);
    }

    final prompt = _buildPrompt(data);
    final uri = Uri.parse('$_endpoint?key=$apiKey');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.5,
          },
        }),
      );

      if (response.statusCode != 200) {
        return _fallback(data);
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      final text =
          responseData['candidates'][0]['content']['parts'][0]['text']
              as String;
      final jsonResult = jsonDecode(text) as Map<String, dynamic>;
      final result = ReportAiSuggestion.fromJson(jsonResult);
      if (result.summary.isEmpty && result.proposals.isEmpty) {
        return _fallback(data);
      }
      return result;
    } catch (_) {
      // 通信エラー・JSON解析失敗等、いずれの理由でもPDF生成自体は
      // 止めず、ルールベースの代替提案に切り替える。
      return _fallback(data);
    }
  }

  String _buildPrompt(ReportData data) {
    return '''
あなたは運送業(トラック輸送)における事故防止・安全管理の専門コンサルタントです。
以下は、ある運送会社の事故統計データ(${data.periodLabel}の分析結果)です。
このデータのみから、多角的な視点で傾向を分析し、事故削減に向けた具体的な取組み提案を
作成してください。

【重要】個人名・社員番号等は一切含まれていません。統計データのみに基づき、
組織的・構造的な観点から分析・提案してください。

【統計データ】
${data.toAiPromptSummary()}

【分析・提案の指針】
- 発生区分・部署・班・部品事故の要因など、複数の軸を掛け合わせた多角的な視点で
  傾向を読み取ってください。
- 提案は、現場で実行可能な具体的な内容にしてください(例: 特定の作業工程での
  確認手順の追加、特定部署への安全教育の強化等)。
- 個人の責任追及ではなく、組織的な仕組み・教育・管理体制の改善を意識してください。
- 運送業(トラック輸送・倉庫作業)の現場感覚に合った内容にしてください。
- 提案は3〜5件程度、それぞれ1〜2文程度の簡潔な文章にしてください。

以下のJSON形式のみで出力してください(説明文は不要):
{
  "summary": "多角的な分析結果の要約(2〜3文程度)",
  "proposals": ["取組み提案1", "取組み提案2", "取組み提案3"]
}
''';
  }

  /// AI呼び出し失敗時のフォールバック。既存のルールベース分析結果から
  /// 簡易な代替提案文を組み立てる(方針Aの考え方を踏襲)。
  ReportAiSuggestion _fallback(ReportData data) {
    final proposals = <String>[];

    // 発生区分の最多カテゴリに応じた一般的な提案。
    if (data.typeBreakdown.isNotEmpty) {
      final sorted = data.typeBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      proposals.add(
        '「${top.key.label}」が最も多く発生しているため、当該区分に関する'
        '安全教育・作業手順の見直しを優先的に実施することを推奨します。',
      );
    }

    // 部品事故要因の最多カテゴリに応じた提案。
    if (data.partsCauseBreakdown.isNotEmpty) {
      final sorted = data.partsCauseBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      proposals.add(
        '部品事故の発生要因では「${top.key.label}」が最多のため、'
        '該当作業における確認手順の再徹底・チェックリスト化を検討してください。',
      );
    }

    // 班別の最多カテゴリに応じた提案。
    final teamEntries = data.teamBreakdown.entries
        .where((e) => e.key.label != '未設定')
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (teamEntries.isNotEmpty && teamEntries.first.value >= 2) {
      proposals.add(
        '${teamEntries.first.key.label}の事故件数が多いため、'
        '班内でのKYT(危険予知訓練)や安全ミーティングの頻度強化を検討してください。',
      );
    }

    // 庸車比率に応じた提案。
    final total = data.charterCount + data.ownCompanyCount;
    if (total > 0 && data.charterCount / total >= 0.3) {
      proposals.add(
        '庸車事故の比率が一定以上を占めているため、委託先への安全指導・'
        '契約時の安全基準の確認強化を検討してください。',
      );
    }

    if (proposals.isEmpty) {
      proposals.add('現時点では特定の傾向が顕著ではありません。継続的なデータ収集と定期分析を推奨します。');
    }

    final summary = data.ruleBasedInsights.isNotEmpty
        ? data.ruleBasedInsights.map((i) => i.message).join(' ')
        : '${data.periodLabel}の事故統計データを集計しました。詳細な傾向は上記の分析結果をご参照ください。';

    return ReportAiSuggestion(
      summary: summary,
      proposals: proposals,
      isFallback: true,
    );
  }
}
