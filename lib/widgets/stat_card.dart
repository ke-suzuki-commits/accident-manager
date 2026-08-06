import 'package:flutter/material.dart';

/// ダッシュボード上部の統計カード。
///
/// PC/スマホの2値切り替えではなく、[LayoutBuilder]で実際に配置された
/// カードの幅を計測し、その幅に比例してパディング・アイコンサイズ・
/// フォントサイズを連続的に算出する。これにより、画面幅がどのサイズで
/// あっても(PCの大きなカード、スマホの狭いカード、その中間のタブレット
/// 幅など)「カードの大きさに対してちょうど良い文字サイズ」に自動で
/// フィットする。
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // カードの実測幅を基準に各サイズを比例計算する。
        // clampで極端な幅(非常に狭い/非常に広い)でも見た目が崩れないよう
        // 上下限を設けている。
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 160.0;

        final padding = (width * 0.11).clamp(10.0, 22.0);
        final iconSize = (width * 0.16).clamp(20.0, 32.0);
        final valueFontSize = (width * 0.135).clamp(15.0, 28.0);
        final labelFontSize = (width * 0.068).clamp(10.5, 15.0);
        final gapSmall = (width * 0.045).clamp(4.0, 10.0);

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: iconSize),
              SizedBox(height: gapSmall),
              // ellipsis(...)による見切れではなく、カード幅に応じて文字自体を
              // 自動縮小させることで、桁数の多い値(例:「あと26件」)でも
              // 全文が確実に見える状態を保つ。
              // ※重要: 親のColumnがcrossAxisAlignment.startのため、
              //   FittedBoxにそのまま渡すと幅の制約がなく(loose constraint)、
              //   縮小対象の基準幅が定まらずスケールが機能しない。
              //   SizedBox(width: double.infinity)で明示的に「カードの
              //   内容幅いっぱい」という制約を与えることで、FittedBoxが
              //   正しくその幅を基準に縮小できるようにする。
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapSmall * 0.3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
