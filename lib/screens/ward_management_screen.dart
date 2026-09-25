import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../providers/app_data_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/reorderable_card_list.dart';
import '../widgets/empty_state.dart';

/// Screen 5: ওয়ার্ড ম্যানেজমেন্ট (CRUD list) — FR-3.1 .. FR-3.4.
class WardManagementScreen extends StatefulWidget {
  final Protisthan protisthan;
  const WardManagementScreen({super.key, required this.protisthan});

  @override
  State<WardManagementScreen> createState() => _WardManagementScreenState();
}

class _WardManagementScreenState extends State<WardManagementScreen> {
  final db = DatabaseHelper.instance;
  List<Ward> _wards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await db.getWardsForProtisthan(widget.protisthan.id!);
    if (!mounted) return;
    setState(() {
      _wards = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final s = Strings.of(context);
    final result = await showWardInputDialog(context, title: s.addWardTitle);
    if (result != null && result.name.isNotEmpty && mounted) {
      await context
          .read<AppDataProvider>()
          .addWard(widget.protisthan.id!, result.name, targetAmount: result.targetAmount);
      _load();
    }
  }

  Future<void> _edit(Ward w) async {
    final s = Strings.of(context);
    final result = await showWardInputDialog(
      context,
      title: s.editWardTitle,
      initialName: w.name,
      initialTargetAmount: w.targetAmount,
    );
    if (result != null && result.name.isNotEmpty && mounted) {
      await context.read<AppDataProvider>().updateWardInfo(
            w,
            name: result.name,
            targetAmount: result.targetAmount,
          );
      _load();
    }
  }

  Future<void> _reorder(List<Ward> ordered) async {
    setState(() => _wards = [for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(sortOrder: i)]);
    await context.read<AppDataProvider>().reorderWards(widget.protisthan, ordered);
  }

  Future<void> _delete(Ward w) async {
    final s = Strings.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteWardTitle,
      message: s.deleteWardMessage(w.name),
    );
    if (confirmed && mounted) {
      await context.read<AppDataProvider>().deleteWard(w.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canManage = role?.canManageStructure ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(s.wardManagementTitle(widget.protisthan.name))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wards.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  message: s.emptyWardsMessage,
                )
              : ReorderableCardList<Ward>(
                  items: _wards,
                  keyOf: (w) => ValueKey(w.uuid),
                  canReorder: canManage,
                  dragTooltip: s.dragToReorder,
                  onReorder: _reorder,
                  padding: safeBodyPadding(context, amount: 12, fab: canManage),
                  itemBuilder: (context, w, dragHandle) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: dragHandle != null ? const EdgeInsets.only(left: 4, right: 8) : null,
                      leading: dragHandle,
                      title: Text(w.name),
                      subtitle: w.targetAmount > 0
                          ? Text(s.wardNisabLine(CurrencyFormatter.format(w.targetAmount)))
                          : null,
                      trailing: canManage
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _edit(w),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(w),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
      floatingActionButton: canManage
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
    );
  }
}
