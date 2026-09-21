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
              : ListView.builder(
                  padding: safeBodyPadding(context, amount: 12, fab: canManage),
                  itemCount: _criteria.length,
                  itemBuilder: (context, index) {
                    final c = _criteria[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
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
                  },
                ),
      floatingActionButton: canManage
          ? FloatingActionButton(onPressed: _add, child: const Icon(Icons.add))
          : null,
    );
  }
}
