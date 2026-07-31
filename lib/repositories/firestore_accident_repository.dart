import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/accident_record.dart';
import 'accident_repository.dart';

/// Firestore(クラウド)を使った事故記録データアクセス実装。
///
/// HiveAccidentRepositoryと同じ`AccidentRepository`インターフェースを
/// 実装しているため、main.dartでのProvider登録を1行差し替えるだけで
/// ローカル保存⇔クラウド共有の切替が可能。
///
/// コレクション名: accident_records
/// ドキュメントID: AccidentRecord.id (uuid)
///
/// 【重要】複合クエリ(where+orderBy)はFirestoreの複合インデックスを
/// 要求してしまうため、ここでは単純なgetAll()のみを提供し、
/// 年度/月ごとの集計・並び替えはAccidentService側でメモリ上で行う設計とする。
class FirestoreAccidentRepository implements AccidentRepository {
  static const String collectionName = 'accident_records';

  final FirebaseFirestore _firestore;

  FirestoreAccidentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  @override
  Future<List<AccidentRecord>> getAll() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => AccidentRecord.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> save(AccidentRecord record) async {
    await _collection.doc(record.id).set(record.toMap());
  }

  @override
  Future<void> saveAll(List<AccidentRecord> records) async {
    // Firestoreのバッチ書き込みは1回あたり最大500件までのため分割する
    const chunkSize = 400;
    for (var i = 0; i < records.length; i += chunkSize) {
      final chunk = records.skip(i).take(chunkSize);
      final batch = _firestore.batch();
      for (final record in chunk) {
        batch.set(_collection.doc(record.id), record.toMap());
      }
      await batch.commit();
    }
  }

  @override
  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}
