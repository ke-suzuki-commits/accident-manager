import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/accident_master.dart';
import '../services/accident_service.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/accident_list_tile.dart';
import 'accident_detail_screen.dart';
import 'accident_form_screen.dart';

/// 事故一覧の並び替え順。
/// デフォルトは発生日時が新しい順（従来の挙動を維持）。
enum AccidentSortOrder {
  occurredDesc('発生日時が新しい順'),
  occurredAsc('発生日時が古い順'),
  noDesc('No.が大きい順'),
  noAsc('No.が小さい順');

  final String label;
  const AccidentSortOrder(this.label);
}

class AccidentListScreen extends StatefulWidget {
  // ダッシュボードの班別目標カードなどから、特定の年度・班に絞り込んだ状態で
  // 直接この一覧を開けるようにするための初期フィルタ値(任意)。
  final int? initialYearFilter;
  final Team? initialTeamFilter;
  // ホーム画面のボトムナビ内タブとして表示する場合はfalse(AppBar無し、
  // ResponsiveShell側のヘッダーを使う)。ダッシュボード等からNavigator.push
  // で単独画面として開く場合はtrueにし、戻るボタン付きのAppBarを表示する。
  final bool standalone;

  const AccidentListScreen({
    super.key,
    this.initialYearFilter,
    this.initialTeamFilter,
    this.standalone = false,
  });

  @override
  State<AccidentListScreen> createState() => _AccidentListScreenState();
}

class _AccidentListScreenState extends State<AccidentListScreen> {
  int? _yearFilter;
  AccidentType? _typeFilter;
  OfficeDept? _officeFilter;
  Team? _teamFilter;
  String _keyword = '';
  AccidentSortOrder _sortOrder = AccidentSortOrder.occurredDesc;

  @override
  void initState() {
    super.initState();
    _yearFilter = widget.initialYearFilter;
    _teamFilter = widget.initialTeamFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccidentService>(
      builder: (context, service, _) {
        final canEdit = context.watch<AuthService>().canEdit;
        var records = service.records;

        if (_yearFilter != null) {
          records = records.where((r) => r.fiscalYear == _yearFilter).toList();
        }
        if (_typeFilter != null) {
          records = records
              .where((r) => r.accidentType == _typeFilter)
              .toList();
        }
        if (_officeFilter != null) {
          records = records.where((r) => r.office == _officeFilter).toList();
        }
        if (_teamFilter != null) {
          records = records.where((r) => r.team == _teamFilter).toList();
        }
        if (_keyword.isNotEmpty) {
          final kw = _keyword.toLowerCase();
          records = records
              .where(
                (r) =>
                    r.no.toString() == kw ||
                    r.location.toLowerCase().contains(kw) ||
                    r.description.toLowerCase().contains(kw) ||
                    r.driverName.toLowerCase().contains(kw) ||
                    r.counterparty.toLowerCase().contains(kw),
              )
              .toList();
        }

        // 並び替え。service.recordsはロード時点で発生日時降順にソート済みだが、
        // ユーザーが選択した順序に応じてここで明示的に並べ替える。
        records = [...records];
        switch (_sortOrder) {
          case AccidentSortOrder.occurredDesc:
            records.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
            break;
          case AccidentSortOrder.occurredAsc:
            records.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
            break;
          case AccidentSortOrder.noDesc:
            records.sort((a, b) => b.no.compareTo(a.no));
            break;
          case AccidentSortOrder.noAsc:
            records.sort((a, b) => a.no.compareTo(b.no));
            break;
        }

        final isDesktop = MediaQuery.of(context).size.width >= 900;

        final body = Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 16,
                16,
                isDesktop ? 24 : 16,
                8,
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'No.・場所・内容・氏名・相手方で検索',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (v) => setState(() => _keyword = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  // 高さを固定するとチップ内の文字が縦方向に見切れることがあるため、
                  // 中身の実際の高さに応じて可変にする(横スクロールのみ固定)。
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      children: [
                        _sortDropdown(),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 24,
                          color: const Color(0xFFE0E0E0),
                        ),
                        const SizedBox(width: 8),
                        _filterDropdownYear(service.availableFiscalYears),
                        const SizedBox(width: 8),
                        _filterDropdownType(),
                        const SizedBox(width: 8),
                        _filterDropdownOffice(),
                        const SizedBox(width: 8),
                        _filterDropdownTeam(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        '該当する事故記録がありません',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90, top: 4),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final r = records[index];
                        return AccidentListTile(
                          record: r,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccidentDetailScreen(record: r),
                            ),
                          ),
                          onEdit: canEdit
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AccidentFormScreen(existing: r),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );

        // ダッシュボードの班別目標カード等からNavigator.pushで単独画面として
        // 開いた場合、ホーム画面のボトムナビ/サイドナビによる戻り手段が無い
        // ため、戻るボタン付きのAppBarで明示的にラップする。
        if (widget.standalone) {
          return Scaffold(
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient,
                ),
              ),
              title: const Text('事故一覧'),
            ),
            body: SafeArea(child: body),
          );
        }
        return body;
      },
    );
  }

  Widget _sortDropdown() {
    return PopupMenuButton<AccidentSortOrder>(
      onSelected: (v) => setState(() => _sortOrder = v),
      itemBuilder: (context) => [
        for (final order in AccidentSortOrder.values)
          PopupMenuItem<AccidentSortOrder>(
            value: order,
            child: Row(
              children: [
                if (order == _sortOrder)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 6),
                Text(order.label),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sort_rounded,
              size: 15,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 5),
            Text(
              _sortOrder.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdownYear(List<int> years) {
    return _FilterChipDropdown<int>(
      label: _yearFilter == null ? '年度' : '$_yearFilter年度',
      selected: _yearFilter != null,
      items: years,
      itemLabel: (y) => '$y年度',
      onSelected: (v) => setState(() => _yearFilter = v),
      onClear: () => setState(() => _yearFilter = null),
    );
  }

  Widget _filterDropdownType() {
    return _FilterChipDropdown<AccidentType>(
      label: _typeFilter?.label ?? '発生区分',
      selected: _typeFilter != null,
      items: AccidentType.values,
      itemLabel: (t) => t.label,
      onSelected: (v) => setState(() => _typeFilter = v),
      onClear: () => setState(() => _typeFilter = null),
    );
  }

  Widget _filterDropdownOffice() {
    return _FilterChipDropdown<OfficeDept>(
      label: _officeFilter?.label ?? '発生部署',
      selected: _officeFilter != null,
      items: OfficeDept.values,
      itemLabel: (o) => o.label,
      onSelected: (v) => setState(() => _officeFilter = v),
      onClear: () => setState(() => _officeFilter = null),
    );
  }

  Widget _filterDropdownTeam() {
    return _FilterChipDropdown<Team>(
      label: _teamFilter?.label ?? '班',
      selected: _teamFilter != null,
      items: Team.values,
      itemLabel: (t) => t.label,
      onSelected: (v) => setState(() => _teamFilter = v),
      onClear: () => setState(() => _teamFilter = null),
    );
  }
}

class _FilterChipDropdown<T> extends StatelessWidget {
  final String label;
  final bool selected;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onSelected;
  final VoidCallback onClear;

  const _FilterChipDropdown({
    required this.label,
    required this.selected,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // 「解除」ボタン部分と「選択」ボタン部分でタップ領域を分離する。
    // Chip+avatarの組み合わせだと、avatar(×アイコン)をタップしても
    // Chip全体がPopupMenuButtonのタップ領域に含まれてしまい、
    // メニューが開くだけで選択解除ができない不具合があったため、
    // 明示的に2つの独立したタップ領域を持つデザインに変更する。
    final chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.secondary.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.4)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.filter_list_rounded,
            size: 15,
            color: selected ? AppColors.secondary : AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          // 文字が見切れないよう、内容に応じて幅が伸びるようにする
          // (固定幅で切ってしまうと選択中のラベルが読めなくなるため)
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.secondary : AppColors.textPrimary,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: AppColors.secondary,
              ),
            ),
          ],
        ],
      ),
    );

    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(value: item, child: Text(itemLabel(item))),
      ],
      child: chipContent,
    );
  }
}
