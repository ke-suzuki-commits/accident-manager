import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'employee_management_screen.dart';
import 'target_setting_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _apiKeySaving = false;
  bool _apiKeyDirty = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _apiKeyCtrl.text = settings.geminiApiKey;
    _userNameCtrl.text = settings.userName;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _userNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUserName() async {
    final settings = context.read<SettingsService>();
    await settings.setUserName(_userNameCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定を保存しました')));
    }
  }

  Future<void> _saveApiKey() async {
    final settings = context.read<SettingsService>();
    final auth = context.read<AuthService>();
    setState(() => _apiKeySaving = true);
    try {
      await settings.setApiKey(
        _apiKeyCtrl.text.trim(),
        updatedBy: auth.currentUser?.name ?? '(不明)',
      );
      if (mounted) {
        setState(() => _apiKeyDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gemini APIキーを更新しました（全社員に共有されます）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _apiKeySaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final auth = context.watch<AuthService>();
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 28 : 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '設定',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _accountCard(context, auth),
            const SizedBox(height: 16),
            if (auth.isAdmin) ...[
              _card(
                title: '管理者メニュー',
                children: [
                  _menuTile(
                    context,
                    icon: Icons.people_alt_rounded,
                    label: '社員アカウント管理',
                    subtitle: '権限の付与・社員の追加',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmployeeManagementScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  _menuTile(
                    context,
                    icon: Icons.flag_rounded,
                    label: '年度事故目標の設定',
                    subtitle: '全社・班別の目標件数',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TargetSettingScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _card(
              title: 'ユーザー情報',
              children: [
                TextField(
                  controller: _userNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '管理者名（原因分析の記録者名として使用されます）',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveUserName,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Gemini APIキーは編集者・管理者のみが使う「AIドラフト生成」機能のための
            // 全社共有設定。費用が発生する社外APIキーのため、登録・変更は管理者限定とする。
            // (生成済み・保存済みのなぜなぜ分析結果自体は閲覧者も参照可能)
            if (auth.isAdmin) _geminiApiKeyCard(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _geminiApiKeyCard(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        // Firestore側の値が変わった場合(他の管理者が変更した/初回読込完了時)、
        // 未編集(dirtyでない)なら表示テキストを追従させる。
        if (!_apiKeyDirty && _apiKeyCtrl.text != settings.geminiApiKey) {
          _apiKeyCtrl.text = settings.geminiApiKey;
        }
        return _card(
          title: 'AI原因分析（Gemini API）',
          children: [
            const Text(
              'なぜなぜ分析のドラフト自動生成にはGemini APIキーが必要です。\n'
              'Google AI Studio（https://aistudio.google.com/）で取得したAPIキーを入力してください。\n'
              'ここで登録したキーは全社員（編集者・管理者）に共有され、AIドラフト生成機能で使用されます。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (settings.isLoadingApiKey)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                onChanged: (_) => setState(() => _apiKeyDirty = true),
                decoration: InputDecoration(
                  labelText: 'Gemini APIキー',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
            if (settings.apiKeyError != null) ...[
              const SizedBox(height: 8),
              Text(
                settings.apiKeyError!,
                style: const TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.cloud_done_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本運用：Firestoreで一元管理しています。ここで保存すると全社員・全端末に即時反映されます。',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_apiKeySaving || settings.isLoadingApiKey)
                    ? null
                    : _saveApiKey,
                child: _apiKeySaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('APIキーを保存'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context, AuthService auth) {
    final user = auth.currentUser;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                child: Text(
                  (user?.name.isNotEmpty ?? false)
                      ? user!.name.substring(0, 1)
                      : '?',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '(不明なユーザー)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  auth.role.label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showChangePasswordDialog(context),
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('パスワード変更'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  // AuthGateがログイン状態の変化を監視して自動的に
                  // LoginScreenへ切り替えるため、ここでのNavigator操作は不要
                  // (むしろAuthGate自体を画面スタックから外してしまい、
                  //  以後のログイン処理が画面に反映されなくなる不具合の原因になっていた)。
                  onPressed: () => context.read<AuthService>().signOut(),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  label: const Text(
                    'ログアウト',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final auth = context.read<AuthService>();
    final ctrl = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('パスワード変更'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '新しいパスワード(6文字以上)',
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (ctrl.text.length < 6) {
                            setState(() => errorMessage = '6文字以上で入力してください');
                            return;
                          }
                          setState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          try {
                            await auth.changePassword(ctrl.text);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('パスワードを変更しました')),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = '$e';
                              isSubmitting = false;
                            });
                          }
                        },
                  child: const Text('変更する'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
