import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
import '../models/criteria.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../providers/app_data_provider.dart';
import '../utils/bangla_utils.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../utils/ward_search.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/reorderable_card_list.dart';
import 'criteria_management_screen.dart';
import 'entry_form_screen.dart';
import 'matrix_report_screen.dart';
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
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.protisthan.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.detailTabWards),
            Tab(text: s.detailTabCriteria),
            Tab(text: s.detailTabReport),
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
  Set<int> _entered = {};
  bool _loading = true;

  /// Search and the বাকি filter, for থানা with many wards.
  final _search = TextEditingController();
  String _query = '';
  bool _pendingOnly = false;

  /// Search is offered once the list no longer fits at a glance.
  static const _searchFrom = 8;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wards = await db.getWardsForProtisthan(widget.protisthan.id!);
    final totals = <int, double>{};
    for (final w in wards) {
      totals[w.id!] = await db.getWardTotal(w.id!, widget.month, widget.year);
    }
    final entered = await db.getWardIdsWithEntries(widget.protisthan.id!, widget.month, widget.year);
    if (!mounted) return;
    setState(() {
      _wards = wards;
      _totals = totals;
      _entered = entered;
      _loading = false;
    });
  }

  void _openEntry(Ward w) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => EntryFormScreen(
            ward: w,
            wards: _wards,
            protisthan: widget.protisthan,
            initialMonth: widget.month,
            initialYear: widget.year,
          ),
        ))
        .then((_) => _load());
  }

  /// Search box, বাকি/সব chips and how many are left, above the list.
  Widget _header(Strings s, int pending, int shown) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_wards.length >= _searchFrom) ...[
          TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: s.wardSearchHint,
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ChoiceChip(
            label: Text(s.wardFilterPending(pending)),
            selected: _pendingOnly,
            onSelected: (_) => setState(() => _pendingOnly = true),
          ),
          ChoiceChip(
            label: Text(s.wardFilterAll(_wards.length)),
            selected: !_pendingOnly,
            onSelected: (_) => setState(() => _pendingOnly = false),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          pending == 0 ? s.wardAllEntered : s.wardPendingLine(pending, _wards.length),
          style: TextStyle(color: pending == 0 ? Colors.green : scheme.onSurfaceVariant, fontSize: 12.5),
        ),
        if (shown == 0 && (_query.isNotEmpty || pending > 0))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(s.wardNoMatch, textAlign: TextAlign.center)),
          ),
      ]),
    );
  }

  Future<void> _addWard() async {
    final s = Strings.of(context);
    final result = await showWardInputDialog(context, title: s.addWardTitle);
    if (result != null && result.name.isNotEmpty && mounted) {
      await context
          .read<AppDataProvider>()
          .addWard(widget.protisthan.id!, result.name, targetAmount: result.targetAmount);
      _load();
    }
  }

  Future<void> _editWard(Ward w) async {
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

  Future<void> _reorderWards(List<Ward> ordered) async {
    setState(() => _wards = [for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(sortOrder: i)]);
    await context.read<AppDataProvider>().reorderWards(widget.protisthan, ordered);
  }

  Future<void> _deleteWard(Ward w) async {
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
    final pending = _wards.where((w) => !_entered.contains(w.id)).length;
    final shown = [
      for (final w in _wards)
        if ((!_pendingOnly || !_entered.contains(w.id)) && WardSearch.matches(w.name, _query)) w,
    ];
    final filtering = _pendingOnly || _query.trim().isNotEmpty;
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wards.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  message: s.emptyWardsMessage,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ReorderableCardList<Ward>(
                    items: shown,
                    keyOf: (w) => ValueKey(w.uuid),
                    // Reordering a filtered part of the list would be confusing.
                    canReorder: canManage && !filtering,
                    header: _header(s, pending, shown.length),
                    dragTooltip: s.dragToReorder,
                    onReorder: _reorderWards,
                    padding: safeBodyPadding(context, amount: 12, fab: canManage),
                    itemBuilder: (context, w, dragHandle) {
                      final total = _totals[w.id] ?? 0;
                      final entered = _entered.contains(w.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          contentPadding: dragHandle != null ? const EdgeInsets.only(left: 4, right: 8) : null,
                          leading: dragHandle,
                          title: Row(children: [
                            Tooltip(
                              message: entered ? s.wardEnteredTooltip : s.wardPendingTooltip,
                              child: Icon(
                                entered ? Icons.check_circle : Icons.hourglass_empty_rounded,
                                size: 18,
                                color: entered ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          ]),
                          subtitle: Text(
                            '${BanglaMonths.label(widget.month, widget.year)} · ${total == 0 ? s.wardEmptyAmount : CurrencyFormatter.format(total)}'
                            '${w.targetAmount > 0 ? '  •  ${s.nisabPrefix(CurrencyFormatter.format(w.targetAmount))}' : ''}',
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
                                  itemBuilder: (context) => [
                                    PopupMenuItem(value: 'edit', child: Text(s.edit)),
                                    PopupMenuItem(value: 'delete', child: Text(s.delete)),
                                    PopupMenuItem(value: 'manage', child: Text(s.wardMenuManageAll)),
                                  ],
                                )
                              : null,
                          onTap: () => _openEntry(w),
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
  List<Criteria> _criteria = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await db.getCriteriaForProtisthan(widget.protisthan.id!);
    if (!mounted) return;
    setState(() {
      _criteria = list;
      _loading = false;
    });
  }

  Future<void> _reorder(List<Criteria> ordered) async {
    setState(() => _criteria = [
          ..._criteria.where((c) => c.isSpecial),
          for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(sortOrder: i),
        ]);
    await context.read<AppDataProvider>().reorderCriteria(widget.protisthan, ordered);
  }

  void _openManagement() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => CriteriaManagementScreen(protisthan: widget.protisthan),
        ))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canManage = role?.canManageStructure ?? false;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ReorderableCardList<Criteria>(
        pinned: _criteria.where((c) => c.isSpecial).toList(),
        items: _criteria.where((c) => !c.isSpecial).toList(),
        keyOf: (c) => ValueKey(c.uuid),
        canReorder: canManage,
        dragTooltip: s.dragToReorder,
        onReorder: _reorder,
        padding: safeBodyPadding(context, amount: 12),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.criteriaCountLabel(_criteria.length), style: theme.textTheme.titleMedium),
                    Text(s.criteriaSameListNote, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.edit),
                label: Text(s.manageCriteriaButton),
                onPressed: _openManagement,
              ),
            ],
          ),
        ),
        itemBuilder: (context, c, dragHandle) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            contentPadding: dragHandle != null ? const EdgeInsets.only(left: 4, right: 16) : null,
            leading: dragHandle ??
                (c.isSpecial ? Icon(Icons.push_pin_outlined, size: 20, color: theme.colorScheme.outline) : null),
            title: Text(c.name),
            subtitle: c.isSpecial ? Text(s.specialCriteriaNote, style: const TextStyle(fontSize: 11.5)) : null,
          ),
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
    final s = Strings.of(context);
    final now = DateTime.now();
    return ListView(
      padding: safeBodyPadding(context),
      children: [
        _SummaryCard(
          icon: Icons.point_of_sale_outlined,
          title: s.thanaIncomeTitle,
          subtitle: s.thanaIncomeSubtitle,
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
          title: s.remittanceCardTitle,
          subtitle: s.remittanceCardSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RemittanceScreen(protisthan: protisthan)),
          ),
        ),
        _SummaryCard(
          icon: Icons.grid_on,
          title: s.matrixCardTitle,
          subtitle: s.matrixCardSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MatrixReportScreen(protisthan: protisthan)),
          ),
        ),
        _SummaryCard(
          icon: Icons.summarize_outlined,
          title: s.summaryCardTitle,
          subtitle: s.summaryCardSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProtisthanSummaryScreen(protisthan: protisthan)),
          ),
        ),
        _SummaryCard(
          icon: Icons.show_chart,
          title: s.trendCardTitle,
          subtitle: s.trendCardSubtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TrendScreen(protisthan: protisthan)),
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
