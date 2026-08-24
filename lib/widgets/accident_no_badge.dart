import 'package:flutter/material.dart';
import '../models/accident_master.dart';
import '../models/accident_record.dart';
import '../theme/app_theme.dart';

/// 事故No.表示用の共通テキスト。
///
/// 役員要望により事故No.は「自社(有責)」「庸車(有責)」の区分別連番となり、
/// 無責・責任区分不明の記録はNo.を持たない(採番対象外)。
/// 一覧・詳細・分析(多重事故者)画面など複数箇所で同じ表示ルールを
/// 使うため、共通ウィジェットとして切り出す。
///
/// 表示ルール:
///   自社(有責) → 「自社No.12」
///   庸車(有責) → 「庸車No.5」(区分が視覚的に区別できるよう secondary 色)
///   無責・責任区分不明 → 「No.―」(採番対象外であることを示す)
class AccidentNoBadge extends StatelessWidget {
  final AccidentRecord record;
  final double fontSize;

  const AccidentNoBadge({super.key, required this.record, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final category = record.numberingCategory;
    final style = TextStyle(
      color: category == NumberingCategory.charter
          ? AppColors.secondary
          : AppColors.textSecondary,
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
    );
    final text = switch (category) {
      NumberingCategory.ownCompany => '自社No.${record.no}',
      NumberingCategory.charter => '庸車No.${record.no}',
      null => 'No.―',
    };
    return Text(text, style: style);
  }
}
