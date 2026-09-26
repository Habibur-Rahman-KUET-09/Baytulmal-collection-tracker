import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
import '../models/criteria.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../providers/app_data_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../utils/ward_search.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/month_picker_field.dart';
import '../utils/number_input.dart';
import 'ward_summary_screen.dart';

/// Screen 6: ডেটা এন্ট্রি ফর্ম — FR-4.1 .. FR-4.6.
///
/// The Protisthan's special আয়/ব্যয় criteria are shown first, in a
/// highlighted section with a live-computed বাস্তব জমা (= আয় − ব্যয়) and a
/// check against the Ward's fixed ধার্যকৃত নিসাব. ধার্যকৃত নিসাব ও বাস্তব
/// জমা — এই দুটোর কোনো ইনপুট এখানে নেই: নিসাব ওয়ার্ড তৈরির সময় ফিক্সড হয়,
/// আর বাস্তব জমা সবসময় আয়-ব্যয় থেকে হিসাব হয় — দুটোই শুধু রেফারেন্স হিসেবে
/// দেখানো হয়। Every other criteria follows exactly as before, unaffected.
///
/// [wards] is the থানা's ward list in its order: the form can then move
/// between wards (◀ ▶, or by picking one) and "save and go to the next
/// ward" jumps to the next one still without an entry this month.
class EntryFormScreen extends StatefulWidget {
  final Ward ward;
  final List<Ward> wards;
  final Protisthan protisthan;
  final int initialMonth;
  final int initialYear;

  const EntryFormScreen({
    super.key,
    required this.ward,
    this.wards = const [],
    required this.protisthan,
    required this.initialMonth,
    required this.initialYear,
  });

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  late int _month;
  late int _year;
  late Ward _ward;
  late final List<Ward> _wards = widget.wards.isEmpty ? [widget.ward] : widget.wards;
  List<Criteria> _criteriaList = [];
  final Map<int, TextEditingController> _controllers = {};

  /// The field texts as loaded, to tell whether anything is unsaved.
  final Map<int, String> _loadedText = {};

  /// Wards with an entry for the month shown.
  Set<int> _entered = {};
  bool _loading = true;
  bool _saving = false;

  int get _index => _wards.indexWhere((w) => w.id == _ward.id);

  int? get _nextPending => WardSearch.nextPending([for (final w in _wards) w.id!], _index, _entered);

  bool get _dirty => _controllers.entries.any((e) => e.value.text.trim() != (_loadedText[e.key] ?? ''));

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
    _ward = widget.ward;
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final criteriaList = await db.getCriteriaForProtisthan(widget.protisthan.id!);
    final existing = await db.getEntriesForWardMonth(_ward.id!, _month, _year);
    final entered = await db.getWardIdsWithEntries(widget.protisthan.id!, _month, _year);

    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _loadedText.clear();
    for (final c in criteriaList) {
      if (c.hasNoEntry) continue; // ধার্যকৃত নিসাব/বাস্তব জমা — কোনো Entry নেই
      final value = existing[c.id];
      final text = value == null ? '' : NumberInput.editable(value);
      _loadedText[c.id!] = text;
      _controllers[c.id!] = TextEditingController(text: text);
    }

    if (!mounted) return;
    setState(() {
      _criteriaList = criteriaList;
      _entered = entered;
      _loading = false;
    });
  }

  /// Opens another ward's entry for the same month, asking first if
  /// something typed here is not saved.
  Future<void> _goTo(Ward ward, {bool askIfUnsaved = true}) async {
    if (ward.id == _ward.id) return;
    if (askIfUnsaved && _dirty) {
      final s = Strings.of(context);
      final leave = await showConfirmDialog(
        context,
        title: s.unsavedChangesTitle,
        message: s.unsavedChangesMessage,
        confirmLabel: s.ok,
        isDestructive: false,
      );
      if (!leave || !mounted) return;
    }
    setState(() => _ward = ward);
    await _load();
  }

  Future<void> _pickWard(Strings s) async {
    final picked = await showModalBottomSheet<Ward>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _WardPicker(wards: _wards, current: _ward, entered: _entered),
    );
    if (picked != null && mounted) await _goTo(picked);
  }


  Future<void> _onMonthChanged(DateTime picked) async {
    setState(() {
      _month = picked.month;
      _year = picked.year;
    });
    await _load();
  }

  Future<void> _save(Strings s, {bool goToNext = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final appData = context.read<AppDataProvider>();
    try {
      for (final c in _criteriaList) {
        if (c.hasNoEntry) continue;
        final text = _controllers[c.id!]!.text.trim();
        final amount = NumberInput.parse(text);
        await appData.saveEntry(
          protisthan: widget.protisthan,
          ward: _ward,
          criteria: c,
          month: _month,
          year: _year,
          amount: amount,
        );
      }
      if (!mounted) return;
      final anyAmount = _controllers.values.any((c) => c.text.trim().isNotEmpty);
      _entered = {..._entered};
      anyAmount ? _entered.add(_ward.id!) : _entered.remove(_ward.id!);
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      final next = goToNext ? _nextPending : null;
      if (next != null) {
        messenger.showSnackBar(SnackBar(content: Text(s.entrySaved), duration: const Duration(seconds: 1)));
        await _goTo(_wards[next], askIfUnsaved: false);
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(goToNext ? s.entrySavedAllDone : s.entrySaved)));
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _criteriaField(Criteria c, {required bool canEnter, required Strings s}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[c.id!],
        enabled: canEnter,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: NumberInput.formatters,
        decoration: InputDecoration(
          labelText: s.amountFieldLabel(c.name),
          hintText: s.amountFieldHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: c.isSpecial ? (_) => setState(() {}) : null,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final parsed = NumberInput.parse(v);
          if (parsed == null) return s.enterValidNumber;
          if (parsed < 0) return s.negativeNotAllowed;
          return null;
        },
      ),
    );
  }

  /// ◀ ward name (position, ✓/⏳) ▶ — tap the name to pick any ward.
  Widget _wardSwitcher(Strings s) {
    final i = _index;
    final entered = _entered.contains(_ward.id);
    return Card(
      margin: EdgeInsets.zero,
      child: Row(children: [
        IconButton(
          tooltip: s.previousWard,
          icon: const Icon(Icons.chevron_left),
          onPressed: i > 0 && !_saving ? () => _goTo(_wards[i - 1]) : null,
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _saving ? null : () => _pickWard(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(
                    entered ? Icons.check_circle : Icons.hourglass_empty_rounded,
                    size: 16,
                    color: entered ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _ward.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ]),
                Text(s.wardPosition(i + 1, _wards.length), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
        IconButton(
          tooltip: s.nextWard,
          icon: const Icon(Icons.chevron_right),
          onPressed: i < _wards.length - 1 && !_saving ? () => _goTo(_wards[i + 1]) : null,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canEnter = role?.canEnterData ?? false;
    final editableSpecialCriteria = _criteriaList.where((c) => c.isSpecial && !c.hasNoEntry).toList();
    final normalCriteria = _criteriaList.where((c) => !c.isSpecial).toList();
    final targetAmount = _ward.targetAmount;
    final next = _nextPending;
    final hasTarget = targetAmount > 0;

    double sumOf(int? specialOrder) {
      final c = editableSpecialCriteria.where((c) => c.specialOrder == specialOrder);
      if (c.isEmpty) return 0;
      return NumberInput.parse(_controllers[c.first.id!]!.text) ?? 0;
    }

    final income = sumOf(2);
    final expense = sumOf(3);
    final actualDeposit = income - expense;
    final matched = hasTarget && (targetAmount - actualDeposit).abs() < 0.005;
    final anySpecialFilled =
        editableSpecialCriteria.any((c) => _controllers[c.id!]!.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.entryFormTitle(_ward.name)),
        actions: [
          IconButton(
            tooltip: s.wardSummaryTooltip,
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WardSummaryScreen(
                  ward: _ward,
                  protisthan: widget.protisthan,
                  initialMonth: _month,
                  initialYear: _year,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: safeBodyPadding(context),
                children: [
                  if (_wards.length > 1) ...[
                    _wardSwitcher(s),
                    const SizedBox(height: 16),
                  ],
                  Text(s.selectMonth, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  MonthPickerField(month: _month, year: _year, onChanged: _onMonthChanged),
                  if (editableSpecialCriteria.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(s.incomeExpenseTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (hasTarget)
                                Text(
                                  s.nisabLine(CurrencyFormatter.format(targetAmount)),
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...editableSpecialCriteria.map((c) => _criteriaField(c, canEnter: canEnter, s: s)),
                          if (anySpecialFilled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: (hasTarget ? (matched ? Colors.green : Colors.orange) : Colors.blueGrey)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    !hasTarget
                                        ? Icons.info_outline
                                        : matched
                                            ? Icons.check_circle_outline
                                            : Icons.info_outline,
                                    size: 18,
                                    color: hasTarget ? (matched ? Colors.green : Colors.orange) : Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      !hasTarget
                                          ? s.actualDepositNoTarget(CurrencyFormatter.format(actualDeposit))
                                          : matched
                                              ? s.actualDepositMatched(CurrencyFormatter.format(actualDeposit))
                                              : s.actualDepositMismatch(
                                                  CurrencyFormatter.format(actualDeposit),
                                                  CurrencyFormatter.format(targetAmount),
                                                ),
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(s.otherCriteriaTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (normalCriteria.isEmpty)
                    EmptyState(
                      icon: Icons.category_outlined,
                      message: s.noExtraCriteriaMessage,
                    )
                  else
                    ...normalCriteria.map((c) => _criteriaField(c, canEnter: canEnter, s: s)),
                  const SizedBox(height: 12),
                  if (canEnter && next != null) ...[
                    FilledButton.icon(
                      onPressed: (_criteriaList.isEmpty || _saving) ? null : () => _save(s, goToNext: true),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(s.saveAndNextWard(_wards[next].name), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: (_criteriaList.isEmpty || _saving) ? null : () => _save(s),
                      child: Text(s.save),
                    ),
                  ] else if (canEnter)
                    FilledButton(
                      onPressed: (_criteriaList.isEmpty || _saving) ? null : () => _save(s),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(s.save),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Bottom sheet listing the থানা's wards with their entry status, with a
/// search box when there are many.
class _WardPicker extends StatefulWidget {
  final List<Ward> wards;
  final Ward current;
  final Set<int> entered;

  const _WardPicker({required this.wards, required this.current, required this.entered});

  @override
  State<_WardPicker> createState() => _WardPickerState();
}

class _WardPickerState extends State<_WardPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final shown = [for (final w in widget.wards) if (WardSearch.matches(w.name, _query)) w];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(s.chooseWard, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (widget.wards.length >= 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: s.wardSearchHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(s.wardNoMatch))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final w = shown[i];
                      final entered = widget.entered.contains(w.id);
                      return ListTile(
                        selected: w.id == widget.current.id,
                        leading: Icon(
                          entered ? Icons.check_circle : Icons.hourglass_empty_rounded,
                          color: entered ? Colors.green : Colors.orange,
                        ),
                        title: Text(w.name),
                        onTap: () => Navigator.of(context).pop(w),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
