import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController();
  bool _obscureKey = true;

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

  Future<void> _save() async {
    final settings = context.read<SettingsService>();
    await settings.setApiKey(_apiKeyCtrl.text.trim());
    await settings.setUserName(_userNameCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定を保存しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
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
            _card(
              title: 'ユーザー情報',
              children: [
                TextField(
                  controller: _userNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '管理者名（原因分析の記録者名として使用されます）',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _card(
              title: 'AI原因分析（Gemini API）',
              children: [
                const Text(
                  'なぜなぜ分析のドラフト自動生成にはGemini APIキーが必要です。\n'
                  'Google AI Studio（https://aistudio.google.com/）で取得したAPIキーを入力してください。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: _obscureKey,
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '暫定運用：現在はアプリ内にキーを保存しています。Firebase接続後はサーバー側(Cloud Functions)で安全に管理する構成に切替予定です。',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: const Text('保存')),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
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
}
