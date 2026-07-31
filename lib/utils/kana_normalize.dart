/// 半角カタカナ(濁点・半濁点を含む)を全角カタカナへ正規化するユーティリティ。
///
/// 【背景・不具合の原因】
/// Excelからの移行データや、ユーザーがIME入力モードを誤って半角のまま
/// 確定してしまった場合、テキストの中に「ｽｽﾞｷ」のような半角カタカナが
/// 混在することがある。半角の濁点(ﾞ, U+FF9E)・半濁点(ﾟ, U+FF9F)は
/// 全角の「゛」「゜」と違い、直前の文字と組み合わさって1文字の
/// グリフになるものではなく、単独の文字コードとして存在する。
/// アプリで使用しているゴシック体フォントにこの単独の濁点/半濁点用の
/// グリフが用意されていないと、画面上では「豆腐(□)」として表示され、
/// 結果として「スズ□キ」のように文字化けして見える不具合が発生する。
///
/// 【対応方針】
/// 半角カタカナ＋(半)濁点の並びを、対応する全角カタカナ1文字
/// (濁音/半濁音を含む)へ変換する。すでに全角の文字列に対しては
/// 何も変換せず、そのまま返す(=何度適用しても結果が変わらない、
/// 冪等な処理)。
library;

String _c(int codePoint) => String.fromCharCode(codePoint);

/// 濁点・半濁点を伴わない半角カタカナ・記号 → 全角
final Map<String, String> _halfKanaBase = {
  _c(0xFF61): _c(0x3002), // 。
  _c(0xFF62): _c(0x300C), // 「
  _c(0xFF63): _c(0x300D), // 」
  _c(0xFF64): _c(0x3001), // 、
  _c(0xFF65): _c(0x30FB), // ・
  _c(0xFF66): _c(0x30F2), // ヲ
  _c(0xFF67): _c(0x30A1), // ァ
  _c(0xFF68): _c(0x30A3), // ィ
  _c(0xFF69): _c(0x30A5), // ゥ
  _c(0xFF6A): _c(0x30A7), // ェ
  _c(0xFF6B): _c(0x30A9), // ォ
  _c(0xFF6C): _c(0x30E3), // ャ
  _c(0xFF6D): _c(0x30E5), // ュ
  _c(0xFF6E): _c(0x30E7), // ョ
  _c(0xFF6F): _c(0x30C3), // ッ
  _c(0xFF70): _c(0x30FC), // ー
  _c(0xFF71): _c(0x30A2), // ア
  _c(0xFF72): _c(0x30A4), // イ
  _c(0xFF73): _c(0x30A6), // ウ
  _c(0xFF74): _c(0x30A8), // エ
  _c(0xFF75): _c(0x30AA), // オ
  _c(0xFF76): _c(0x30AB), // カ
  _c(0xFF77): _c(0x30AD), // キ
  _c(0xFF78): _c(0x30AF), // ク
  _c(0xFF79): _c(0x30B1), // ケ
  _c(0xFF7A): _c(0x30B3), // コ
  _c(0xFF7B): _c(0x30B5), // サ
  _c(0xFF7C): _c(0x30B7), // シ
  _c(0xFF7D): _c(0x30B9), // ス
  _c(0xFF7E): _c(0x30BB), // セ
  _c(0xFF7F): _c(0x30BD), // ソ
  _c(0xFF80): _c(0x30BF), // タ
  _c(0xFF81): _c(0x30C1), // チ
  _c(0xFF82): _c(0x30C4), // ツ
  _c(0xFF83): _c(0x30C6), // テ
  _c(0xFF84): _c(0x30C8), // ト
  _c(0xFF85): _c(0x30CA), // ナ
  _c(0xFF86): _c(0x30CB), // ニ
  _c(0xFF87): _c(0x30CC), // ヌ
  _c(0xFF88): _c(0x30CD), // ネ
  _c(0xFF89): _c(0x30CE), // ノ
  _c(0xFF8A): _c(0x30CF), // ハ
  _c(0xFF8B): _c(0x30D2), // ヒ
  _c(0xFF8C): _c(0x30D5), // フ
  _c(0xFF8D): _c(0x30D8), // ヘ
  _c(0xFF8E): _c(0x30DB), // ホ
  _c(0xFF8F): _c(0x30DE), // マ
  _c(0xFF90): _c(0x30DF), // ミ
  _c(0xFF91): _c(0x30E0), // ム
  _c(0xFF92): _c(0x30E1), // メ
  _c(0xFF93): _c(0x30E2), // モ
  _c(0xFF94): _c(0x30E4), // ヤ
  _c(0xFF95): _c(0x30E6), // ユ
  _c(0xFF96): _c(0x30E8), // ヨ
  _c(0xFF97): _c(0x30E9), // ラ
  _c(0xFF98): _c(0x30EA), // リ
  _c(0xFF99): _c(0x30EB), // ル
  _c(0xFF9A): _c(0x30EC), // レ
  _c(0xFF9B): _c(0x30ED), // ロ
  _c(0xFF9C): _c(0x30EF), // ワ
  _c(0xFF9D): _c(0x30F3), // ン
};

/// 直後に半角濁点(ﾞ)が続くと濁音になる文字 → 濁音の全角カタカナ
final Map<String, String> _halfKanaDakuten = {
  _c(0xFF73): _c(0x30F4), // ウ→ヴ
  _c(0xFF76): _c(0x30AC), // カ→ガ
  _c(0xFF77): _c(0x30AE), // キ→ギ
  _c(0xFF78): _c(0x30B0), // ク→グ
  _c(0xFF79): _c(0x30B2), // ケ→ゲ
  _c(0xFF7A): _c(0x30B4), // コ→ゴ
  _c(0xFF7B): _c(0x30B6), // サ→ザ
  _c(0xFF7C): _c(0x30B8), // シ→ジ
  _c(0xFF7D): _c(0x30BA), // ス→ズ ★「スズキ」等
  _c(0xFF7E): _c(0x30BC), // セ→ゼ
  _c(0xFF7F): _c(0x30BE), // ソ→ゾ
  _c(0xFF80): _c(0x30C0), // タ→ダ
  _c(0xFF81): _c(0x30C2), // チ→ヂ
  _c(0xFF82): _c(0x30C5), // ツ→ヅ
  _c(0xFF83): _c(0x30C7), // テ→デ
  _c(0xFF84): _c(0x30C9), // ト→ド
  _c(0xFF8A): _c(0x30D0), // ハ→バ
  _c(0xFF8B): _c(0x30D3), // ヒ→ビ
  _c(0xFF8C): _c(0x30D6), // フ→ブ
  _c(0xFF8D): _c(0x30D9), // ヘ→ベ
  _c(0xFF8E): _c(0x30DC), // ホ→ボ
};

/// 直後に半角半濁点(ﾟ)が続くと半濁音になる文字(ハ行のみ) → 半濁音の全角カタカナ
final Map<String, String> _halfKanaHandakuten = {
  _c(0xFF8A): _c(0x30D1), // ハ→パ
  _c(0xFF8B): _c(0x30D4), // ヒ→ピ
  _c(0xFF8C): _c(0x30D7), // フ→プ
  _c(0xFF8D): _c(0x30DA), // ヘ→ペ
  _c(0xFF8E): _c(0x30DD), // ホ→ポ
};

const int _kDakuten = 0xFF9E; // ﾞ
const int _kHandakuten = 0xFF9F; // ﾟ

/// 文字列中の半角カタカナ(＋濁点/半濁点)を全角カタカナに正規化する。
/// 全角文字や日本語以外の文字はそのまま保持する。
/// 何度適用しても結果が変わらない(冪等)ため、表示直前・保存直前の
/// どちらで呼んでも安全。
String normalizeHalfWidthKana(String input) {
  if (input.isEmpty) return input;
  final runes = input.runes.toList();
  final result = <int>[];
  var i = 0;
  while (i < runes.length) {
    final ch = String.fromCharCode(runes[i]);
    final base = _halfKanaBase[ch];
    if (base != null) {
      if (i + 1 < runes.length) {
        final nextCp = runes[i + 1];
        if (nextCp == _kDakuten && _halfKanaDakuten.containsKey(ch)) {
          result.addAll(_halfKanaDakuten[ch]!.runes);
          i += 2;
          continue;
        }
        if (nextCp == _kHandakuten && _halfKanaHandakuten.containsKey(ch)) {
          result.addAll(_halfKanaHandakuten[ch]!.runes);
          i += 2;
          continue;
        }
      }
      result.addAll(base.runes);
      i += 1;
      continue;
    }
    if (runes[i] == _kDakuten) {
      // 結合先が無い孤立した半角濁点 → 全角の濁点記号として保持
      result.add(0x309B);
      i += 1;
      continue;
    }
    if (runes[i] == _kHandakuten) {
      result.add(0x309C);
      i += 1;
      continue;
    }
    result.add(runes[i]);
    i += 1;
  }
  return String.fromCharCodes(result);
}
