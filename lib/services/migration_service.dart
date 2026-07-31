import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/accident_record.dart';
import 'accident_service.dart';

/// Excel過去データ(assets/migrated_accidents.json)を初回起動時に
/// 自動でDB(Firestore/Hive)へ取り込むサービス。
///
/// 【重要・冪等性(何度実行しても結果が変わらないこと)の設計】
/// 以前はSharedPreferences(ブラウザ/端末ごとのローカルストレージ)で
/// 「実行済みフラグ」を管理していたが、これは以下の問題があった:
///   - 別のブラウザ・別の端末で開くたびに「初回」と判定され、
///     クラウド共有DB(Firestore)に同じデータが重複投入される
///   - 複数タブ/複数端末からほぼ同時にアクセスした場合、
///     「まだデータが空か」の判定が競合(レースコンディション)し、
///     二重投入されることがある
/// これを解決するため、移行データの各レコードに
/// "migrated_連番" という固定ID(例: migrated_001)を割り当てる。
/// 固定IDでの保存(Firestoreのset)は「上書き」になるため、
/// 何度・どこから実行しても重複が発生しない設計とする。
class MigrationService {
  Future<void> runIfNeeded(AccidentService accidentService) async {
    // すでに移行済みデータ(id="migrated_xxx")が1件でも存在する場合は
    // 再実行しない(クラウド上のデータそのものを判定基準にする)。
    final alreadyMigrated = accidentService.records.any(
      (r) => r.id.startsWith('migrated_'),
    );
    if (alreadyMigrated) return;

    try {
      final jsonStr = await rootBundle.loadString(
        'assets/migrated_accidents.json',
      );
      final List<dynamic> list = jsonDecode(jsonStr);
      final records = list.map((e) {
        final map = Map<String, dynamic>.from(e as Map<String, dynamic>);
        final no = map['no'] as int? ?? 0;
        map['id'] = 'migrated_${no.toString().padLeft(3, '0')}';
        return AccidentRecord.fromMap(map);
      }).toList();
      await accidentService.importRecords(records);
    } catch (_) {
      // アセットが存在しない場合は静かにスキップ（初回セットアップ以外の環境向け）
    }
  }
}
