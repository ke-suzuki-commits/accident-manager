import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/accident_record.dart';
import 'accident_service.dart';

/// Excel過去データ(assets/migrated_accidents.json)を初回起動時に
/// 自動でローカルDBへ取り込むサービス。
/// 一度取り込んだら再実行しないよう SharedPreferences でフラグ管理する。
class MigrationService {
  static const _flagKey = 'excel_migration_done_v1';

  Future<void> runIfNeeded(AccidentService accidentService) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_flagKey) == true) return;

    try {
      final jsonStr = await rootBundle.loadString(
        'assets/migrated_accidents.json',
      );
      final List<dynamic> list = jsonDecode(jsonStr);
      final records = list
          .map((e) => AccidentRecord.fromMap(e as Map<String, dynamic>))
          .toList();
      await accidentService.importRecords(records);
      await prefs.setBool(_flagKey, true);
    } catch (_) {
      // アセットが存在しない場合は静かにスキップ（初回セットアップ以外の環境向け）
    }
  }
}
