import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../providers/app_data_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';

/// Screen 4: ক্রাইটেরিয়া ম্যানেজমেন্ট (CRUD list) — FR-2.1 .. FR-2.5.
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
      title: 'নতুন ক্রাইটেরিয়া যোগ করুন',
      label: 'ক্রাইটেরিয়ার নাম',
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
      title: 'ক্রাইটেরিয়ার নাম সম্পাদনা',
      label: 'ক্রাইটেরিয়ার নাম',
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
      title: 'ক্রাইটেরিয়া মুছে ফেলুন?',
      message: '"${c.name}" মুছে ফেললে সকল ওয়ার্ডের এই ক্রাইটেরিয়া সংক্রান্ত এন্ট্রি ডেটাও মুছে যাবে।',
    );
    if (confirmed && mounted) {
      await context.read<AppDataProvider>().deleteCriteria(c.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ক্রাইটেরিয়া (${widget.protisthan.name})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _criteria.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  message: 'কোনো ক্রাইটেরিয়া যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি ক্রাইটেরিয়া যোগ করুন।',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _criteria.length,
                  itemBuilder: (context, index) {
                    final c = _criteria[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: c.isSpecial
                            ? const Text(
                                'বিশেষ ক্রাইটেরিয়া — নির্ধারিত লক্ষ্যমাত্রার সাথে সম্পর্কিত',
                                style: TextStyle(fontSize: 11.5),
                              )
                            : null,
                        trailing: Row(
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
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
    );
  }
}
