import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../providers/app_data_provider.dart';
import '../utils/bangla_utils.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
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
    final result = await showProtisthanInputDialog(
      context,
      title: 'নতুন থানা যোগ করুন',
    );
    if (result != null && result.name.isNotEmpty && context.mounted) {
      await context.read<AppDataProvider>().addProtisthan(result.name, thanaNisab: result.nisab);
    }
  }

  Future<void> _editProtisthan(BuildContext context, Protisthan p) async {
    final thanaWard = await DatabaseHelper.instance.getThanaWard(p.id!);
    if (!context.mounted) return;
    final result = await showProtisthanInputDialog(
      context,
      title: 'থানার নাম সম্পাদনা',
      initialName: p.name,
      initialNisab: thanaWard?.targetAmount ?? 0,
    );
    if (result != null && result.name.isNotEmpty && context.mounted) {
      await context.read<AppDataProvider>().renameProtisthan(p, result.name, thanaNisab: result.nisab);
    }
  }

  Future<void> _deleteProtisthan(BuildContext context, Protisthan p) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'থানা মুছে ফেলুন?',
      message:
          '"${p.name}" মুছে ফেললে এর সকল ওয়ার্ড, খাত এবং এন্ট্রি ডেটাও স্থায়ীভাবে মুছে যাবে। এই কাজটি ফিরিয়ে নেওয়া যাবে না।',
    );
    if (confirmed && context.mounted) {
      await context.read<AppDataProvider>().deleteProtisthan(p.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppDataProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('বাইতুলমাল কালেকশন ট্র্যাকার'),
        actions: [
          IconButton(
            tooltip: 'ডেটা ব্যবস্থাপনা (এক্সপোর্ট/ইমপোর্ট)',
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DataManagementScreen()),
            ),
          ),
          IconButton(
            tooltip: 'আমার অ্যাকাউন্ট',
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
              ? const EmptyState(
                  icon: Icons.account_balance_outlined,
                  message: 'কোনো থানা যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি থানা যোগ করুন।',
                )
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ListView.builder(
                    padding: safeBodyPadding(context, amount: 12, fab: true),
                    itemCount: provider.protisthanList.length,
                    itemBuilder: (context, index) {
                      final p = provider.protisthanList[index];
                      final wardCount = provider.wardCounts[p.id] ?? 0;
                      final criteriaCount = provider.criteriaCounts[p.id] ?? 0;
                      final role = provider.roleFor(p);
                      final canEdit = role?.canManageStructure ?? false;
                      final canDelete = role?.canDeleteProtisthan ?? false;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${BanglaMonths.toBanglaDigits(wardCount)}টি ওয়ার্ড · ${BanglaMonths.toBanglaDigits(criteriaCount)}টি খাত',
                          ),
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
                              const PopupMenuItem(value: 'members', child: Text('সদস্য ব্যবস্থাপনা')),
                              if (canEdit)
                                const PopupMenuItem(value: 'edit', child: Text('নাম সম্পাদনা')),
                              if (canDelete)
                                const PopupMenuItem(value: 'delete', child: Text('মুছে ফেলুন')),
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
