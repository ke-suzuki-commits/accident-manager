import 'package:hive/hive.dart';
import '../models/accident_record.dart';

/// 事故記録データアクセスの抽象インターフェース。
/// 現状はHive(ローカル)実装だが、Firebase接続後は
/// FirestoreAccidentRepositoryを実装して差し替えるだけで良い設計。
abstract class AccidentRepository {
  Future<List<AccidentRecord>> getAll();
  Future<void> save(AccidentRecord record);
  Future<void> delete(String id);
  Future<void> saveAll(List<AccidentRecord> records);
}

class HiveAccidentRepository implements AccidentRepository {
  static const String boxName = 'accident_records';

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return Hive.openBox(boxName);
  }

  @override
  Future<List<AccidentRecord>> getAll() async {
    final box = await _box();
    return box.values
        .map(
          (e) => AccidentRecord.fromMap(Map<dynamic, dynamic>.from(e as Map)),
        )
        .toList();
  }

  @override
  Future<void> save(AccidentRecord record) async {
    final box = await _box();
    await box.put(record.id, record.toMap());
  }

  @override
  Future<void> saveAll(List<AccidentRecord> records) async {
    final box = await _box();
    final map = {for (final r in records) r.id: r.toMap()};
    await box.putAll(map);
  }

  @override
  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
  }
}
