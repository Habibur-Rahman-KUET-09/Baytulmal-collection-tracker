import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
import '../models/criteria.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../providers/app_data_provider.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/drag_handle.dart';
import '../widgets/empty_state.dart';

/// Screen 4: খাত ম্যানেজমেন্ট (CRUD list) — FR-2.1 .. FR-2.5.
class CriteriaManagementScreen extends StatefulWidget {
  final Protisthan protisthan;
  const CriteriaManagementScreen({super.key, required this.protisthan});

  @override
  State<CriteriaManagementScreen> createState() => _CriteriaManagementScreenState();
}

class _CriteriaManagementScreenState extends State<CriteriaManagementScreen> {
  final db = DatabaseHelper.instance;
  List<Criteria> _criteria = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await db.getCriteriaForProtisthan(widget.protisthan.id!);
    if (!mounted) return;
    setState(() {
      _criteria = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final s = Strings.of(context);
    final name = await showNameInputDialog(
      context,
      title: s.addCriteriaTitle,
      label: s.criteriaNameLabel,
      hintText: s.criteriaNameHint,
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<AppDataProvider>().addCriteria(widget.protisthan.id!, name);
      _load();
    }
  }

  Future<void> _rename(Criteria c) async {
    final s = Strings.of(context);
    final name = await showNameInputDialog(
      context,
      title: s.editCriteriaTitle,
      label: s.criteriaNameLabel,
      initialValue: c.name,
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<AppDataProvider>().renameCriteria(c, name);
      _load();
    }
  }

  Future<void> _delete(Criteria c) async {
    final s = Strings.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteCriteriaTitle,
      message: s.deleteCriteriaMessage(c.name),
    );
    if (confirmed && mounted) {
      await context.read<AppDataProvider>().deleteCriteria(c.id!);
      _load();
    }
  }

  // Special criteria stay first in their fixed order; only normal ones move.
  List<Criteria> get _special => _criteria.where((c) => c.isSpecial).toList();
  List<Criteria> get _normal => _criteria.where((c) => !c.isSpecial).toList();

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final normal = _normal;
    normal.insert(newIndex, normal.removeAt(oldIndex));
    setState(() => _criteria = [
          ..._special,
          for (var i = 0; i < normal.length; i++) normal[i].copyWith(sortOrder: i),
        ]);
    await context.read<AppDataProvider>().reorderCriteria(widget.protisthan, normal);
  }

  Widget _criteriaCard(Criteria c, {required bool canManage, int? dragIndex}) {
    final s = Strings.of(context);
    return Card(
      key: ValueKey(c.uuid),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: dragIndex != null ? const EdgeInsets.only(left: 4, right: 8) : null,
        leading: dragIndex != null ? DragHandle(index: dragIndex, tooltip: s.dragToReorder) : null,
        title: Text(c.name),
        subtitle: c.isSpecial
            ? Text(
                s.specialCriteriaNote,
                style: const TextStyle(fontSize: 11.5),
              )
            : null,
        trailing: !canManage
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _rename(c),
                  ),
                  if (!c.isSpecial)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(c),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canManage = role?.canManageStructure ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(s.criteriaManagementTitle(widget.protisthan.name))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _criteria.isEmpty
              ? EmptyState(
                  icon: Icons.category_outlined,
                  message: s.emptyCriteriaMessage,
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: safeBodyPadding(context, amount: 12, fab: canManage).copyWith(bottom: 0),
                      sliver: SliverList.list(
                        children: [for (final c in _special) _criteriaCard(c, canManage: canManage)],
                      ),
                    ),
                    SliverPadding(
                      padding: safeBodyPadding(context, amount: 12, fab: canManage).copyWith(top: 0),
                      sliver: SliverReorderableList(
                        itemCount: _normal.length,
                        onReorderItem: _reorder,
                        itemBuilder: (context, index) => _criteriaCard(
                          _normal[index],
                          canManage: canManage,
                          dragIndex: canManage ? index : null,
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: canManage
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
    );
  }
}
