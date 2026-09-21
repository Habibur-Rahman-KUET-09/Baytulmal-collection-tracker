import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../providers/app_data_provider.dart';
import '../utils/bangla_utils.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import 'criteria_management_screen.dart';
import 'entry_form_screen.dart';
import 'matrix_report_screen.dart';
import 'member_management_screen.dart';
import 'protisthan_summary_screen.dart';
import 'remittance_screen.dart';
import 'thana_income_screen.dart';
import 'trend_screen.dart';
import 'ward_management_screen.dart';

/// Screen 3: প্রতিষ্ঠান বিস্তারিত — tabs for Ward list, Criteria shortcut,
/// and Report shortcuts (FR-1.5).
class ProtisthanDetailScreen extends StatefulWidget {
  final Protisthan protisthan;
  const ProtisthanDetailScreen({super.key, required this.protisthan});

  @override
  State<ProtisthanDetailScreen> createState() => _ProtisthanDetailScreenState();
}

class _ProtisthanDetailScreenState extends State<ProtisthanDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.protisthan.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'ওয়ার্ড সমূহ'),
            Tab(text: 'খাত'),
            Tab(text: 'রিপোর্ট'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WardsTab(protisthan: widget.protisthan, month: now.month, year: now.year),
          _CriteriaTab(protisthan: widget.protisthan),
          _SummaryTab(protisthan: widget.protisthan),
        ],
      ),
    );
  }
}

class _WardsTab extends StatefulWidget {
  final Protisthan protisthan;
  final int month;
  final int year;
  const _WardsTab({required this.protisthan, required this.month, required this.year});

  @override
  State<_WardsTab> createState() => _WardsTabState();
}

class _WardsTabState extends State<_WardsTab> {
  final db = DatabaseHelper.instance;
  List<Ward> _wards = [];
  Map<int, double> _totals = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wards = await db.getWardsForProtisthan(widget.protisthan.id!);
    final totals = <int, double>{};
    for (final w in wards) {
      totals[w.id!] = await db.getWardTotal(w.id!, widget.month, widget.year);
    }
    if (!mounted) return;
    setState(() {
      _wards = wards;
      _totals = totals;
      _loading = false;
    });
  }

  Future<void> _addWard() async {
    final result = await showWardInputDialog(context, title: 'নতুন ওয়ার্ড যোগ করুন');
    if (result != null && result.name.isNotEmpty && mounted) {
      await context
          .read<AppDataProvider>()
          .addWard(widget.protisthan.id!, result.name, targetAmount: result.targetAmount);
      _load();
    }
  }

  Future<void> _editWard(Ward w) async {
    final result = await showWardInputDialog(
      context,
      title: 'ওয়ার্ড সম্পাদনা',
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

  Future<void> _deleteWard(Ward w) async {
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
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canManage = role?.canManageStructure ?? false;
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wards.isEmpty
              ? const EmptyState(
                  icon: Icons.storefront_outlined,
                  message: 'কোনো ওয়ার্ড যোগ করা হয়নি।\nনিচের + বোতাম চেপে একটি ওয়ার্ড যোগ করুন।',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: safeBodyPadding(context, amount: 12),
                    itemCount: _wards.length,
                    itemBuilder: (context, index) {
                      final w = _wards[index];
                      final total = _totals[w.id] ?? 0;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${BanglaMonths.label(widget.month, widget.year)} · ${total == 0 ? '৳ ০ (খালি)' : CurrencyFormatter.format(total)}'
                            '${w.targetAmount > 0 ? '  •  ধার্যকৃত নিসাব ${CurrencyFormatter.format(w.targetAmount)}' : ''}',
                          ),
                          trailing: canManage
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') _editWard(w);
                                    if (value == 'delete') _deleteWard(w);
                                    if (value == 'manage') {
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                            builder: (_) => WardManagementScreen(protisthan: widget.protisthan),
                                          ))
                                          .then((_) => _load());
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(value: 'edit', child: Text('সম্পাদনা')),
                                    PopupMenuItem(value: 'delete', child: Text('মুছে ফেলুন')),
                                    PopupMenuItem(value: 'manage', child: Text('সব ওয়ার্ড ম্যানেজ করুন')),
                                  ],
                                )
                              : null,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(
                                builder: (_) => EntryFormScreen(
                                  ward: w,
                                  protisthan: widget.protisthan,
                                  initialMonth: widget.month,
                                  initialYear: widget.year,
                                ),
                              ))
                              .then((_) => _load()),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: canManage
          ? FloatingActionButton(onPressed: _addWard, child: const Icon(Icons.add))
          : null,
    );
  }
}

class _CriteriaTab extends StatefulWidget {
  final Protisthan protisthan;
  const _CriteriaTab({required this.protisthan});

  @override
  State<_CriteriaTab> createState() => _CriteriaTabState();
}

class _CriteriaTabState extends State<_CriteriaTab> {
  final db = DatabaseHelper.instance;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await db.getCriteriaForProtisthan(widget.protisthan.id!);
    if (!mounted) return;
    setState(() => _count = list.length);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              '${BanglaMonths.toBanglaDigits(_count)}টি খাত নির্ধারিত আছে',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'এই থানার সকল ওয়ার্ডের জন্য একই খাত তালিকা ব্যবহৃত হয়।',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('খাত ম্যানেজ করুন'),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                    builder: (_) => CriteriaManagementScreen(protisthan: widget.protisthan),
                  ))
                  .then((_) => _load()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final Protisthan protisthan;
  const _SummaryTab({required this.protisthan});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ListView(
      padding: safeBodyPadding(context),
      children: [
        _SummaryCard(
          icon: Icons.point_of_sale_outlined,
          title: 'থানার আয়',
          subtitle: 'থানার নিজস্ব কালেকশন, খাত অনুযায়ী',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ThanaIncomeScreen(
                protisthan: protisthan,
                initialMonth: now.month,
                initialYear: now.year,
              ),
            ),
          ),
        ),
        _SummaryCard(
          icon: Icons.account_balance_outlined,
          title: 'থানার বাস্তব জমা খরচ',
          subtitle: 'সব ওয়ার্ডের বাস্তব জমা ও থানার ব্যয়ের হিসাব',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RemittanceScreen(protisthan: protisthan)),
          ),
        ),
        _SummaryCard(
          icon: Icons.grid_on,
          title: 'ম্যাট্রিক্স রিপোর্ট',
          subtitle: 'ওয়ার্ড × খাত টেবিল — PDF/Excel এক্সপোর্ট করুন',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MatrixReportScreen(protisthan: protisthan)),
          ),
        ),
        _SummaryCard(
          icon: Icons.summarize_outlined,
          title: 'থানার মাসিক কালেকশন এক নজরে',
          subtitle: 'মোট কালেকশন, খাত ও ওয়ার্ড অনুযায়ী বিভাজন',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProtisthanSummaryScreen(protisthan: protisthan)),
          ),
        ),
        _SummaryCard(
          icon: Icons.show_chart,
          title: 'ট্রেন্ড / তুলনা',
          subtitle: 'একাধিক মাসের কালেকশন গ্রাফ আকারে তুলনা করুন',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TrendScreen(protisthan: protisthan)),
          ),
        ),
        _SummaryCard(
          icon: Icons.group_outlined,
          title: 'সদস্য ব্যবস্থাপনা',
          subtitle: 'এই থানার সদস্য তালিকা, রোল ও প্রবেশাধিকার',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MemberManagementScreen(protisthan: protisthan)),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
