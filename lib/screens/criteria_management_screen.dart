import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
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
    final name = await showNameInputDialog(
      context,
      title: 'নতুন খাত যোগ করুন',
      label: 'খাতের নাম',
      hintText: 'যেমনঃ দোকান ভাড়া',
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<AppDataProvider>().addCriteria(widget.protisthan.id!, name);
      _load();
    }
  }

  Future<void> _rename(Criteria c) async {
    final name = await showNameInputDialog(
      context,
      title: 'খাতের নাম সম্পাদনা',
      label: 'খাতের নাম',
      initialValue: c.name,
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<AppDataProvider>().renameCriteria(c, name);
      _load();
    }
  }

  Future<void> _delete(Criteria c) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'খাত মুছে ফেলুন?',
      message: '"${c.name}" মুছে ফেললে সকল ওয়ার্ডের এই খাত সংক্রান্ত এন্ট্রি ডেটাও মুছে যাবে।',
    );
    if (confirmed && mounted) {
      await context.read<AppDataProvider>().deleteCriteria(c.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canManage = role?.canManageStructure ?? false;
    return Scaffold(
      appBar: AppBar(title: Text('খাত (${widget.protisthan.name})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _criteria.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  message: 'কোনো খাত যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি খাত যোগ করুন।',
                )
              : ListView.builder(
                  padding: safeBodyPadding(context, amount: 12),
                  itemCount: _criteria.length,
                  itemBuilder: (context, index) {
                    final c = _criteria[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: c.isSpecial
                            ? const Text(
                                'বিশেষ খাত — ধার্যকৃত নিসাবের সাথে সম্পর্কিত',
                                style: TextStyle(fontSize: 11.5),
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
