import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// PC幅ではサイドナビ、スマホ幅ではボトムナビに自動切替する共通シェル
class ResponsiveShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.body,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  static const _items = [
    (icon: Icons.dashboard_rounded, label: 'ダッシュボード'),
    (icon: Icons.list_alt_rounded, label: '事故一覧'),
    (icon: Icons.insights_rounded, label: '傾向分析'),
    (icon: Icons.settings_rounded, label: '設定'),
  ];

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildSideNav(context),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDesktopHeader(context),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        items: _items
            .map(
              (it) =>
                  BottomNavigationBarItem(icon: Icon(it.icon), label: it.label),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }

  Widget _buildSideNav(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            alignment: Alignment.centerLeft,
            child: const Text(
              '事故履歴管理\nアイデックス',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _items.length; i++)
            _SideNavItem(
              icon: _items[i].icon,
              label: _items[i].label,
              selected: currentIndex == i,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? AppColors.secondary
                      : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.secondary
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
