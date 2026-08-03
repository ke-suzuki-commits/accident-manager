import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ設定を管理するサービス。
///
/// - Gemini APIキー: 全社共有の設定のため Firestore(`app_settings/gemini`)で管理する。
///   管理者が1回登録すれば、全社員・全端末で即時共有される(本運用)。
///   ブラウザのキャッシュクリアやハードリロードで消えることはない。
/// - ユーザー名(記録者名): 個人ごとのローカル設定のため、端末ローカル(shared_preferences)のまま管理する。
///
/// 【重要】Firestoreの`app_settings`読み取りにはログイン済みであることが必須(セキュリティルール)。
/// そのためAPIキーの監視(snapshots)はFirebase Authのログイン状態と連動させ、
/// ログアウト時は必ず監視を停止する。停止しないと、ログアウト後も監視が
/// permission-deniedエラーを受け続け、直後のログイン処理に悪影響を及ぼすため。
class SettingsService extends ChangeNotifier {
  static const _keyUserName = 'user_name';
  static const String _collectionName = 'app_settings';
  static const String _geminiDocId = 'gemini';

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  String _geminiApiKey = '';
  String _userName = '';
  bool _isLoadingApiKey = true;
  String? _apiKeyError;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _apiKeySub;

  /// [firestore]・[auth]がnull(=Firebase未接続)の場合は、APIキーの共有機能を
  /// 無効化し、業務が止まらないよう安全側(キー未設定状態)にフォールバックする。
  SettingsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore,
      _auth = auth;

  String get geminiApiKey => _geminiApiKey;
  String get userName => _userName;
  bool get hasApiKey => _geminiApiKey.isNotEmpty;
  bool get isLoadingApiKey => _isLoadingApiKey;
  String? get apiKeyError => _apiKeyError;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString(_keyUserName) ?? '';
    notifyListeners();

    final firestore = _firestore;
    final auth = _auth;
    if (firestore == null || auth == null) {
      // Firebase未接続時はAPIキー共有機能を利用できない。
      _isLoadingApiKey = false;
      _apiKeyError = 'Firebaseに接続できていないため、Gemini APIキーを取得できません。';
      notifyListeners();
      return;
    }

    // ログイン状態の変化に連動してFirestore監視を開始/停止する。
    _authSub = auth.authStateChanges().listen((user) {
      _apiKeySub?.cancel();
      _apiKeySub = null;

      if (user == null) {
        // ログアウト中はFirestoreの`app_settings`を読む権限がないため、
        // 監視を張らない(張るとpermission-deniedが残留し、後続のログイン
        // 処理に悪影響を及ぼす)。表示上もキー未設定として扱う。
        _geminiApiKey = '';
        _isLoadingApiKey = false;
        _apiKeyError = null;
        notifyListeners();
        return;
      }

      _isLoadingApiKey = true;
      notifyListeners();
      _apiKeySub = firestore
          .collection(_collectionName)
          .doc(_geminiDocId)
          .snapshots()
          .listen(
            (doc) {
              _geminiApiKey = doc.data()?['apiKey'] as String? ?? '';
              _isLoadingApiKey = false;
              _apiKeyError = null;
              notifyListeners();
            },
            onError: (e) {
              _isLoadingApiKey = false;
              _apiKeyError = 'Gemini APIキーの取得に失敗しました: $e';
              notifyListeners();
            },
          );
    });
  }

  /// 管理者がGemini APIキーを設定する(Firestore経由・全社共有)。
  Future<void> setApiKey(String key, {required String updatedBy}) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firebaseに接続できていないため、APIキーを保存できません。');
    }
    await firestore.collection(_collectionName).doc(_geminiDocId).set({
      'apiKey': key,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
    // snapshots()のリスナーが即時反映するが、通信タイムラグを避けるため即時にも反映しておく。
    _geminiApiKey = key;
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    _userName = name;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _apiKeySub?.cancel();
    super.dispose();
  }
}
