import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../providers/app_data_provider.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/drag_handle.dart';
import '../widgets/empty_state.dart';
import 'account_screen.dart';
import 'data_management_screen.dart';
import 'member_management_screen.dart';
import 'protisthan_detail_screen.dart';

/// Screen 1: প্রতিষ্ঠান তালিকা (Home) — FR-1.1, FR-1.2.
class ProtisthanListScreen extends StatefulWidget {
  const ProtisthanListScreen({super.key});

  @override
  State<ProtisthanListScreen> createState() => _ProtisthanListScreenState();
}

class _ProtisthanListScreenState extends State<ProtisthanListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppDataProvider>().refresh();
    });
  }

  Future<void> _addProtisthan(BuildContext context) async {
    final s = Strings.of(context);
    final result = await showProtisthanInputDialog(
      context,
      title: s.homeAddProtisthanTitle,
    );
    if (result != null && result.name.isNotEmpty && context.mounted) {
      await context.read<AppDataProvider>().addProtisthan(result.name, thanaNisab: result.nisab);
    }
  }

  Future<void> _editProtisthan(BuildContext context, Protisthan p) async {
    final s = Strings.of(context);
    final thanaWard = await DatabaseHelper.instance.getThanaWard(p.id!);
    if (!context.mounted) return;
    final result = await showProtisthanInputDialog(
      context,
      title: s.homeEditProtisthanTitle,
      initialName: p.name,
      initialNisab: thanaWard?.targetAmount ?? 0,
    );
    if (result != null && result.name.isNotEmpty && context.mounted) {
      await context.read<AppDataProvider>().renameProtisthan(p, result.name, thanaNisab: result.nisab);
    }
  }

  Future<void> _deleteProtisthan(BuildContext context, Protisthan p) async {
    final s = Strings.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: s.homeDeleteProtisthanTitle,
      message: s.homeDeleteProtisthanMessage(p.name),
    );
    if (confirmed && context.mounted) {
      await context.read<AppDataProvider>().deleteProtisthan(p.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppDataProvider>();
    final s = Strings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appTitle),
        actions: [
          IconButton(
            tooltip: s.homeDataManagementTooltip,
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DataManagementScreen()),
            ),
          ),
          IconButton(
            tooltip: s.homeAccountTooltip,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),
        ],
      ),
      body: provider.isLoading && provider.protisthanList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.protisthanList.isEmpty
              ? EmptyState(
                  icon: Icons.account_balance_outlined,
                  message: s.homeEmptyMessage,
                )
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ReorderableListView.builder(
                    padding: safeBodyPadding(context, amount: 12, fab: true),
                    buildDefaultDragHandles: false,
                    itemCount: provider.protisthanList.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final list = [...provider.protisthanList];
                      list.insert(newIndex, list.removeAt(oldIndex));
                      provider.reorderProtisthans(list);
                    },
                    itemBuilder: (context, index) {
                      final p = provider.protisthanList[index];
                      final wardCount = provider.wardCounts[p.id] ?? 0;
                      final criteriaCount = provider.criteriaCounts[p.id] ?? 0;
                      final role = provider.roleFor(p);
                      final canEdit = role?.canManageStructure ?? false;
                      final canDelete = role?.canDeleteProtisthan ?? false;
                      return Card(
                        key: ValueKey(p.uuid),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 4, right: 4),
                          leading: DragHandle(index: index, tooltip: s.dragToReorder),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(s.homeWardCriteriaCount(wardCount, criteriaCount)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'members') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => MemberManagementScreen(protisthan: p)),
                                );
                              }
                              if (value == 'edit') _editProtisthan(context, p);
                              if (value == 'delete') _deleteProtisthan(context, p);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'members', child: Text(s.homeMembersMenuItem)),
                              if (canEdit)
                                PopupMenuItem(value: 'edit', child: Text(s.rename)),
                              if (canDelete)
                                PopupMenuItem(value: 'delete', child: Text(s.delete)),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ProtisthanDetailScreen(protisthan: p)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addProtisthan(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
