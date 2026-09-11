import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../providers/app_data_provider.dart';
import '../widgets/confirm_dialog.dart';
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
    final name = await showNameInputDialog(
      context,
      title: 'নতুন ওয়ার্ড যোগ করুন',
      label: 'ওয়ার্ডের নাম',
      hintText: 'যেমনঃ ওয়ার্ড ৬',
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<AppDataProvider>().addWard(widget.protisthan.id!, name);
      _load();
    }
  }

  Future<void> _rename(Ward w) async {
    final name = await showNameInputDialog(
      context,
      title: 'ওয়ার্ডের নাম সম্পাদনা',
      label: 'ওয়ার্ডের নাম',
      initialValue: w.name,
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<AppDataProvider>().renameWard(w, name);
      _load();
    }
  }

  Future<void> _delete(Ward w) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'ওয়ার্ড মুছে ফেলুন?',
      message: '"${w.name}" মুছে ফেললে এর সকল এন্ট্রি ডেটাও স্থায়ীভাবে মুছে যাবে।',
    );
    if (confirmed && mounted) {
      await context.read<AppDataProvider>().deleteWard(w.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ওয়ার্ড সমূহ (${widget.protisthan.name})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wards.isEmpty
              ? const EmptyState(
                  icon: Icons.storefront_outlined,
                  message: 'কোনো ওয়ার্ড যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি ওয়ার্ড যোগ করুন।',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _wards.length,
                  itemBuilder: (context, index) {
                    final w = _wards[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(w.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _rename(w),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(w),
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
