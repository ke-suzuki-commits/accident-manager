import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/accident_record.dart';

/// なぜなぜ分析(4回)＋真因のAIドラフト生成結果
class AiAnalysisResult {
  final String why1;
  final String why2;
  final String why3;
  final String why4;
  final String rootCause;

  AiAnalysisResult({
    required this.why1,
    required this.why2,
    required this.why3,
    required this.why4,
    required this.rootCause,
  });

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AiAnalysisResult(
      why1: json['why1']?.toString() ?? '',
      why2: json['why2']?.toString() ?? '',
      why3: json['why3']?.toString() ?? '',
      why4: json['why4']?.toString() ?? '',
      rootCause: json['rootCause']?.toString() ?? '',
    );
  }
}

class AiAnalysisException implements Exception {
  final String message;
  AiAnalysisException(this.message);
  @override
  String toString() => message;
}

/// Gemini APIを用いたなぜなぜ分析ドラフト生成サービス。
///
/// 【重要・暫定実装に関する注記】
/// 本来はAPIキー漏洩防止のためCloud Functions等のサーバー経由で呼び出すべきだが、
/// 現時点ではFirebaseが未接続のため、暫定的にクライアントから直接Gemini APIを
/// 呼び出す実装としている。Firebase接続後は、この呼び出しをCloud Functions経由に
/// 差し替えることを推奨(呼び出し元のインターフェースは変更不要な設計にしてある)。
class AiAnalysisService {
  // 注記: gemini-2.0-flash / gemini-2.5-flash 系は提供終了(廃止)により
  // 新規ユーザーが利用できないため、動作確認済みの gemini-flash-latest
  // (実体: gemini-3.6-flash) を使用する。
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  Future<AiAnalysisResult> generateCauseAnalysis({
    required String apiKey,
    required AccidentRecord record,
  }) async {
    if (apiKey.isEmpty) {
      throw AiAnalysisException('Gemini APIキーが設定されていません。設定画面で登録してください。');
    }

    final prompt = _buildPrompt(record);

    final uri = Uri.parse('$_endpoint?key=$apiKey');
    late http.Response response;
    try {
      response = await http.post(
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
            'temperature': 0.4,
          },
        }),
      );
    } catch (e) {
      throw AiAnalysisException('通信エラーが発生しました: $e');
    }

    if (response.statusCode != 200) {
      throw AiAnalysisException(
        'AI分析の生成に失敗しました (HTTP ${response.statusCode})。APIキーをご確認ください。',
      );
    }

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final text =
          data['candidates'][0]['content']['parts'][0]['text'] as String;
      final jsonResult = jsonDecode(text) as Map<String, dynamic>;
      return AiAnalysisResult.fromJson(jsonResult);
    } catch (e) {
      throw AiAnalysisException('AI応答の解析に失敗しました: $e');
    }
  }

  String _buildPrompt(AccidentRecord record) {
    return '''
あなたは運送業(トラック輸送)における事故の原因分析専門家です。
以下の事故情報から、「なぜなぜ分析」を4段階で行い、最終的な真因(root cause)を導出してください。

【事故情報】
- 発生部署: ${record.office.label}
- 班: ${record.team.label}
- 発生区分: ${record.accidentType.label}
${record.partsCause != null ? '- 部品事故の発生要因: ${record.partsCause!.label}' : ''}
- 発生場所: ${record.location}
- 発生内容: ${record.description}

【分析の指針】
- why1は直接的な事象、why2〜4は徐々に管理・仕組み・教育面など背景要因へ深掘りしてください。
- 個人の責任追及ではなく、再発防止に繋がる構造的要因を意識してください。
- 運送業の現場感覚に合った具体的な内容にしてください。

以下のJSON形式のみで出力してください（説明文は不要）:
{
  "why1": "...",
  "why2": "...",
  "why3": "...",
  "why4": "...",
  "rootCause": "..."
}
''';
  }
}
