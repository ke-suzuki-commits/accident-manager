/// フォーム入力欄の数値パースを安全に行うためのユーティリティ。
///
/// 【背景・不具合の原因】
/// これまで金額・年齢等の数値項目は `double.tryParse(text) ?? 0` の
/// ように、パースに失敗した場合は黙って0(またはnull)にフォールバック
/// していた。しかし賠償金額のような桁数の多い数値は、ユーザーが
/// カンマ区切り(例: "1,500,000")や全角数字(例: "１５０万")、
/// 円マーク付き(例: "150000円")で入力してしまうことが実運用では
/// 頻繁に起こる。これらは `double.tryParse` では一律パース失敗と
/// なり、エラー表示もされないまま入力値が0円に差し替わって
/// 保存されてしまう ―― という「入力して更新しても反映されない
/// (むしろ消える)」不具合の直接原因になっていた。
///
/// 【対応方針】
/// 1. パース前に、全角数字→半角、カンマ・円マーク・空白等の
///    数値と紛らわしい記号を除去する前処理を行う。
/// 2. それでもパースできない場合は「0円として保存」ではなく、
///    呼び出し側でエラーとして扱えるよう null を返す
///    (フォームのバリデーションでユーザーに気付かせる)。
library;

/// 全角数字(０-９)を半角数字(0-9)に変換する。
String _toHalfWidthDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0xFF10 && rune <= 0xFF19) {
      buffer.writeCharCode(rune - 0xFF10 + 0x30);
    } else if (rune == 0xFF0E) {
      // ．(全角ピリオド) → .
      buffer.write('.');
    } else if (rune == 0xFF0D || rune == 0x2212) {
      // －/− (全角マイナス類) → -
      buffer.write('-');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// 数値入力欄向けの前処理: 全角数字を半角化し、カンマ・円マーク・
/// 空白(全角/半角)・「円」などの単位文字を除去する。
/// 例: "１,５００,０００円" → "1500000"
String sanitizeNumericInput(String raw) {
  var s = _toHalfWidthDigits(raw.trim());
  // カンマ、円マーク、全角/半角スペース、「円」「¥」を除去。
  s = s.replaceAll(RegExp(r'[,\uFF0C\u00A5¥円\s\u3000]'), '');
  return s;
}

/// 金額・年齢等の数値入力欄を安全にdoubleへ変換する。
/// 空文字は0を返す(未入力=金額なし、として扱う既存仕様を踏襲)。
/// 空文字以外でパースできない場合はnullを返すため、呼び出し側で
/// バリデーションエラーとしてユーザーに提示すること。
double? parseAmountOrNull(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 0;
  final sanitized = sanitizeNumericInput(trimmed);
  if (sanitized.isEmpty) return null;
  return double.tryParse(sanitized);
}

/// 年齢・勤続年数等の整数入力欄を安全にintへ変換する。
/// 空文字はnullを返す(未入力=不明、として扱う既存仕様を踏襲)。
/// 空文字以外でパースできない場合もnullを返すため、必要に応じて
/// 呼び出し側でバリデーションすること。
int? parseIntOrNull(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final sanitized = sanitizeNumericInput(trimmed);
  if (sanitized.isEmpty) return null;
  return int.tryParse(sanitized);
}
