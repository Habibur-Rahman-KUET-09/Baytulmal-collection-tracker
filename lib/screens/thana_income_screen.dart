import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// থানার আয় — থানার নিজস্ব প্রত্যক্ষ কালেকশন। খাত (normal criteria) অনুযায়ী
/// ইনপুটের পাশাপাশি আয় (special criteria ২) এর জন্যও একটা আলাদা,
/// ওয়ার্ডের এন্ট্রি ফর্মের মতো হাইলাইটেড ইনপুট থাকে — ধার্যকৃত নিসাব(১)
/// থানা তৈরির সময় ফিক্সড হয় ([DatabaseHelper.ensureThanaWard]/
/// [DatabaseHelper.updateThanaWardTarget]) তাই এখানে ইনপুট নেই, শুধু
/// রেফারেন্স হিসেবে দেখানো হয়। থানার ব্যয়(৩) এখানে কখনো এন্ট্রি হয় না
/// (আলাদাভাবে "থানার বাস্তব জমা খরচ" পাতায় মাসিক ম্যানুয়াল ফিগার) — তাই
/// বাস্তব জমা(৪) সবসময় আয়(২)-এর সমান, এখানে শুধু রেফারেন্স হিসেবে দেখানো
/// হয়, কোনো Entry হয় না। সংরক্ষণ হয় প্রতিষ্ঠানের হিডেন ভার্চুয়াল
/// থানা-ওয়ার্ডের বিপরীতে (দেখুন [DatabaseHelper.getThanaWard]), যাতে
/// ওয়ার্ড/এন্ট্রি সংক্রান্ত বিদ্যমান মেশিনারি পুনঃব্যবহার করা যায়।
class ThanaIncomeScreen extends StatefulWidget {
  final Protisthan protisthan;
  final int initialMonth;
  final int initialYear;

  const ThanaIncomeScreen({
    super.key,
    required this.protisthan,
    required this.initialMonth,
    required this.initialYear,
  });

  @override
  State<ThanaIncomeScreen> createState() => _ThanaIncomeScreenState();
}

class _ThanaIncomeScreenState extends State<ThanaIncomeScreen> {
  final db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();

  late int _month;
  late int _year;
  Ward? _thanaWard;
  double _thanaTargetAmount = 0;
  Criteria? _incomeCriteria;
  List<Criteria> _normalCriteria = [];
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
    final thanaWard = await db.getThanaWard(widget.protisthan.id!);
    final criteriaList = await db.getCriteriaForProtisthan(widget.protisthan.id!);
    final normalCriteria = criteriaList.where((c) => !c.isSpecial).toList();
    final incomeCriteria = criteriaList.firstWhere((c) => c.specialOrder == 2);
    final existing = thanaWard == null
        ? <int, double>{}
        : await db.getEntriesForWardMonth(thanaWard.id!, _month, _year);

    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final c in [incomeCriteria, ...normalCriteria]) {
      final value = existing[c.id];
      _controllers[c.id!] = TextEditingController(
        text: value == null ? '' : _trimZero(value),
      );
    }

    if (!mounted) return;
    setState(() {
      _thanaWard = thanaWard;
      _thanaTargetAmount = thanaWard?.targetAmount ?? 0;
      _incomeCriteria = incomeCriteria;
      _normalCriteria = normalCriteria;
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
    final thanaWard = _thanaWard;
    if (thanaWard == null) return;
    setState(() => _saving = true);
    final appData = context.read<AppDataProvider>();
    try {
      final allCriteria = [?_incomeCriteria, ..._normalCriteria];
      for (final c in allCriteria) {
        final text = _controllers[c.id!]!.text.trim();
        final amount = text.isEmpty ? null : double.parse(text);
        await appData.saveEntry(
          protisthan: widget.protisthan,
          ward: thanaWard,
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

  Widget _criteriaField(Criteria c, {ValueChanged<String>? onChanged, required bool canEnter, required Strings s}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[c.id!],
        enabled: canEnter,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: s.amountFieldLabel(c.name),
          hintText: s.amountFieldHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final parsed = double.tryParse(v.trim());
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
    final incomeCriteria = _incomeCriteria;
    final incomeText = incomeCriteria == null ? '' : (_controllers[incomeCriteria.id!]?.text.trim() ?? '');
    final income = double.tryParse(incomeText) ?? 0;
    final hasTarget = _thanaTargetAmount > 0;
    final matched = hasTarget && (_thanaTargetAmount - income).abs() < 0.005;
    final incomeFilled = incomeText.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(s.thanaIncomeTitle)),
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
                  if (incomeCriteria != null) ...[
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
                                child: Text(s.incomeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (hasTarget)
                                Text(
                                  s.nisabLine(CurrencyFormatter.format(_thanaTargetAmount)),
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _criteriaField(incomeCriteria, onChanged: (_) => setState(() {}), canEnter: canEnter, s: s),
                          if (incomeFilled)
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
                                          ? s.actualDepositIncomeOnlyNoTarget(CurrencyFormatter.format(income))
                                          : matched
                                              ? s.actualDepositIncomeOnlyMatched(CurrencyFormatter.format(income))
                                              : s.actualDepositIncomeOnlyMismatch(
                                                  CurrencyFormatter.format(income),
                                                  CurrencyFormatter.format(_thanaTargetAmount),
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
                  Text(
                    s.criteriaByThanaTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_normalCriteria.isEmpty)
                    EmptyState(
                      icon: Icons.category_outlined,
                      message: s.noThanaCriteriaMessage,
                    )
                  else
                    ..._normalCriteria.map((c) => _criteriaField(c, canEnter: canEnter, s: s)),
                  const SizedBox(height: 12),
                  if (canEnter)
                    FilledButton(
                      onPressed: _saving ? null : () => _save(s),
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
