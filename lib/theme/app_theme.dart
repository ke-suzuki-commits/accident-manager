import 'package:flutter/material.dart';
import '../models/accident_master.dart';

/// カラフル・モダンデザイン（スタイル2）のカラーパレット
class AppColors {
  static const primary = Color(0xFF00BFA5); // teal
  static const secondary = Color(0xFF7C4DFF); // purple
  static const gradientStart = Color(0xFF00BFA5);
  static const gradientEnd = Color(0xFF7C4DFF);

  static const cardTeal = Color(0xFF26C6DA);
  static const cardPurple = Color(0xFF9575CD);
  static const cardPink = Color(0xFFEC407A);
  static const cardYellow = Color(0xFFFFB74D);

  static const background = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1E1E2E);
  static const textSecondary = Color(0xFF8A8DA0);

  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const danger = Color(0xFFE53935);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 発生区分ごとのタグ色（Excel由来の9区分＋クレーム）
  static Color forAccidentType(AccidentType type) {
    switch (type) {
      case AccidentType.traffic:
        return const Color(0xFFE53935); // 赤
      case AccidentType.property:
        return const Color(0xFF43A047); // 緑
      case AccidentType.parts:
        return const Color(0xFF1E88E5); // 青
      case AccidentType.product:
        return const Color(0xFF8E24AA); // 紫
      case AccidentType.delivery:
        return const Color(0xFFFF7043); // オレンジ
      case AccidentType.info:
        return const Color(0xFF546E7A); // グレー系
      case AccidentType.labor:
        return const Color(0xFFD81B60); // ピンク
      case AccidentType.environment:
        return const Color(0xFF00897B); // ティール
      case AccidentType.ruleViolation:
        return const Color(0xFFFFB300); // 黄
      case AccidentType.claim:
        return const Color(0xFF6D4C41); // 茶
    }
  }

  static Color forStatus(RecordStatus status) {
    switch (status) {
      case RecordStatus.reported:
        return warning;
      case RecordStatus.analyzed:
        return success;
    }
  }
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    // 【修正】google_fontsは実行時にNoto Sans JPをネットワーク経由(fonts.gstatic.com)で
    // 取得する仕様のため、取得失敗時にウィジェット再描画が繰り返しクラッシュし、
    // 「事故一覧」画面の灰色オーバーレイや年度チップの表示崩れの原因になっていた。
    // OS/ブラウザ標準搭載のゴシック体フォントスタックを直接指定することで、
    // ネットワーク依存を排除しつつゴシック体統一の方針を維持する。
    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamilyFallback: const [
        'Noto Sans JP',
        'Hiragino Sans',
        'Hiragino Kaku Gothic ProN',
        'Yu Gothic UI',
        'Meiryo',
        'sans-serif',
      ],
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
