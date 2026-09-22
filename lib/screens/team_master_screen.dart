import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/accident_master.dart';
import '../models/team_master.dart';
import '../services/auth_service.dart';
import '../services/team_master_service.dart';
import '../theme/app_theme.dart';

/// 班マスタ(現在の班長・メンバー構成)の管理画面。管理者のみ編集可能。
class TeamMasterScreen extends StatelessWidget {
  const TeamMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final teamMasterService = context.watch<TeamMasterService>();
    final teams = Team.values.where((t) => t != Team.unassigned).toList();

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: const Text('班編成管理'),
      ),
      body: teamMasterService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: teamMasterService.loadTeams,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  final team = teams[index];
                  final master = teamMasterService.masterFor(team);
                  return _teamCard(context, team, master, auth.isAdmin);
                },
              ),
            ),
    );
  }

  Widget _teamCard(
    BuildContext context,
    Team team,
    TeamMaster master,
    bool isAdmin,
  ) {
    final hasLeader = master.leaderName.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAdmin ? () => _openEditDialog(context, team, master) : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                team.label.substring(0, 1),
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLeader ? '班長: ${master.leaderName}' : '班長: 未設定',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasLeader
                          ? AppColors.textSecondary
                          : AppColors.danger,
                      fontWeight: hasLeader
                          ? FontWeight.w600
                          : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '所属人数: ${master.memberCount}名',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    Team team,
    TeamMaster master,
  ) async {
    final auth = context.read<AuthService>();
    final teamMasterService = context.read<TeamMasterService>();
    final leaderCtrl = TextEditingController(text: master.leaderName);
    final memberCtrls = master.memberNames
        .map((m) => TextEditingController(text: m))
        .toList();
    bool isSaving = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${team.label}の編成'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: leaderCtrl,
                        decoration: const InputDecoration(
                          labelText: '班長 氏名',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'メンバー氏名',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(
                                () => memberCtrls.add(TextEditingController()),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('追加'),
                          ),
                        ],
                      ),
                      ...List.generate(memberCtrls.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: memberCtrls[i],
                                  decoration: InputDecoration(
                                    labelText: 'メンバー${i + 1}',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: AppColors.danger,
                                ),
                                onPressed: () {
                                  setState(() {
                                    memberCtrls[i].dispose();
                                    memberCtrls.removeAt(i);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          try {
                            await teamMasterService.saveTeamMaster(
                              team: team,
                              leaderName: leaderCtrl.text,
                              memberNames: memberCtrls
                                  .map((c) => c.text)
                                  .toList(),
                              updatedBy: auth.currentUser?.name ?? '(不明)',
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = '$e';
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('保存する'),
                ),
              ],
            );
          },
        );
      },
    );
    leaderCtrl.dispose();
    for (final c in memberCtrls) {
      c.dispose();
    }
  }
}
