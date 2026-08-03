/// アプリ利用者の権限レベル。
///
/// - viewer  : 閲覧のみ(編集不可)
/// - editor  : 事故記録の新規登録・編集が可能
/// - admin   : editorの全権限 + 社員(ユーザー)の権限管理・年度目標の設定
enum UserRole {
  viewer('閲覧者'),
  editor('編集者'),
  admin('管理者');

  final String label;
  const UserRole(this.label);

  static UserRole fromName(String? name) {
    return UserRole.values.firstWhere(
      (e) => e.name == name,
      orElse: () => UserRole.viewer,
    );
  }

  bool get canEdit => this == editor || this == admin;
  bool get isAdmin => this == admin;
}

/// Firestoreの`users`コレクションに対応する社員アカウント情報。
/// ドキュメントIDはFirebase AuthのUIDと一致させる。
class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  AppUser copyWith({String? name, UserRole? role}) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? createdAt;
    final rawCreatedAt = map['created_at'];
    if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }
    return AppUser(
      uid: uid,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      role: UserRole.fromName(map['role'] as String?),
      createdAt: createdAt,
    );
  }
}
