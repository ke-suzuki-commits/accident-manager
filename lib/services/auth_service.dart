import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

/// 認証状態・権限(role)を一元管理するサービス。
///
/// - Firebase Authenticationでログイン状態を管理
/// - Firestoreの`users/{uid}`ドキュメントからroleを取得
/// - 社員の追加はセカンダリのFirebaseAppインスタンス経由で行うことで、
///   管理者自身のログインセッションを維持したまま新規アカウントを作成できる
///   (Client SDKでは通常createUserと同時に新規ユーザーへ切り替わってしまうため)
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isLoading = true;
  String? _error;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  User? get firebaseUser => _firebaseUser;
  AppUser? get currentUser => _appUser;
  bool get isLoggedIn => _firebaseUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserRole get role => _appUser?.role ?? UserRole.viewer;
  bool get canEdit => role.canEdit;
  bool get isAdmin => role.isAdmin;

  void _onAuthStateChanged(User? user) {
    _firebaseUser = user;
    _userDocSub?.cancel();
    if (user == null) {
      _appUser = null;
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    _userDocSub = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (doc) {
            _appUser = doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = 'ユーザー情報の取得に失敗しました: $e';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> signIn(String email, String password) async {
    _error = null;
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('ログインしていません。');
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw StateError(_mapAuthError(e));
    }
  }

  /// 管理者が新しい社員アカウントを追加する。
  Future<void> createEmployee({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (!isAdmin) {
      throw StateError('管理者のみ社員を追加できます。');
    }
    final secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryAuth_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      await _firestore
          .collection('users')
          .doc(uid)
          .set(
            AppUser(
              uid: uid,
              name: name,
              email: email.trim(),
              role: role,
            ).toMap(),
          );
      await secondaryAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw StateError(_mapAuthError(e));
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> updateUserRole(String uid, UserRole role) async {
    if (!isAdmin) {
      throw StateError('管理者のみ権限を変更できます。');
    }
    await _firestore.collection('users').doc(uid).update({'role': role.name});
  }

  Future<void> removeUser(String uid) async {
    if (!isAdmin) {
      throw StateError('管理者のみ社員を削除できます。');
    }
    if (uid == _firebaseUser?.uid) {
      throw StateError('自分自身のアカウントは削除できません。');
    }
    await _firestore.collection('users').doc(uid).delete();
  }

  Stream<List<AppUser>> watchUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
                ..sort(
                  (a, b) => (a.createdAt ?? DateTime(2000)).compareTo(
                    b.createdAt ?? DateTime(2000),
                  ),
                ),
        );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが正しくありません。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に登録されています。';
      case 'weak-password':
        return 'パスワードは6文字以上で設定してください。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'too-many-requests':
        return 'しばらく時間をおいてから再度お試しください。';
      case 'operation-not-allowed':
        return 'メール/パスワード認証が有効になっていません。管理者にご連絡ください。';
      case 'requires-recent-login':
        return 'セキュリティのため再ログインが必要です。一度ログアウトしてから再度お試しください。';
      default:
        return '認証エラーが発生しました: ${e.message}';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
