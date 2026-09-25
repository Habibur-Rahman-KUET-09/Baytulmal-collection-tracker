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
class EntryFormScreen extends StatefulWidget {
  final Ward ward;
  final Protisthan protisthan;
  final int initialMonth;
  final int initialYear;

  const EntryFormScreen({
    super.key,
    required this.ward,
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
  List<Criteria> _criteriaList = [];
  final Map<int, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
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
    final existing = await db.getEntriesForWardMonth(widget.ward.id!, _month, _year);

    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final c in criteriaList) {
      if (c.hasNoEntry) continue; // ধার্যকৃত নিসাব/বাস্তব জমা — কোনো Entry নেই
      final value = existing[c.id];
      _controllers[c.id!] = TextEditingController(
        text: value == null ? '' : _trimZero(value),
      );
    }

    if (!mounted) return;
    setState(() {
      _criteriaList = criteriaList;
      _loading = false;
    });
  }

  String _trimZero(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  Future<void> _onMonthChanged(DateTime picked) async {
    setState(() {
      _month = picked.month;
      _year = picked.year;
    });
    await _load();
  }

  Future<void> _save(Strings s) async {
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
          ward: widget.ward,
          criteria: c,
          month: _month,
          year: _year,
          amount: amount,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.entrySaved)),
      );
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

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canEnter = role?.canEnterData ?? false;
    final editableSpecialCriteria = _criteriaList.where((c) => c.isSpecial && !c.hasNoEntry).toList();
    final normalCriteria = _criteriaList.where((c) => !c.isSpecial).toList();
    final targetAmount = widget.ward.targetAmount;
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
        title: Text(s.entryFormTitle(widget.ward.name)),
        actions: [
          IconButton(
            tooltip: s.wardSummaryTooltip,
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WardSummaryScreen(
                  ward: widget.ward,
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
                  if (canEnter)
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
