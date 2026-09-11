import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../providers/app_data_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/month_picker_field.dart';
import 'ward_summary_screen.dart';

/// Screen 6: ডেটা এন্ট্রি ফর্ম — FR-4.1 .. FR-4.6.
///
/// The Protisthan's special আদায়/বকেয়া criteria are shown first, in a
/// highlighted section with a live check against the Ward's fixed
/// নির্ধারিত লক্ষ্যমাত্রা (আদায় + বকেয়া = লক্ষ্যমাত্রা); every other
/// criteria follows exactly as before, unaffected.
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final appData = context.read<AppDataProvider>();
    try {
      for (final c in _criteriaList) {
        final text = _controllers[c.id!]!.text.trim();
        final amount = text.isEmpty ? null : double.parse(text);
        await db.saveEntry(
          wardId: widget.ward.id!,
          criteriaId: c.id!,
          month: _month,
          year: _year,
          amount: amount,
          uuidFactory: appData.newUuid(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('এন্ট্রি সংরক্ষণ করা হয়েছে')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _criteriaField(Criteria c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _controllers[c.id!],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: '${c.name} (৳)',
          hintText: 'খালি',
          border: const OutlineInputBorder(),
        ),
        onChanged: c.isSpecial ? (_) => setState(() {}) : null,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final parsed = double.tryParse(v.trim());
          if (parsed == null) return 'সঠিক সংখ্যা দিন';
          if (parsed < 0) return 'ঋণাত্মক মান গ্রহণযোগ্য নয়';
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final specialCriteria = _criteriaList.where((c) => c.isSpecial).toList();
    final normalCriteria = _criteriaList.where((c) => !c.isSpecial).toList();
    final hasTarget = widget.ward.targetAmount > 0;

    double sumOf(int? specialOrder) {
      final c = specialCriteria.where((c) => c.specialOrder == specialOrder);
      if (c.isEmpty) return 0;
      return double.tryParse(_controllers[c.first.id!]!.text.trim()) ?? 0;
    }

    final collected = sumOf(2);
    final due = sumOf(3);
    final specialSum = collected + due;
    final matched = hasTarget && (specialSum - widget.ward.targetAmount).abs() < 0.005;
    final anySpecialFilled =
        specialCriteria.any((c) => _controllers[c.id!]!.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ward.name} — এন্ট্রি'),
        actions: [
          IconButton(
            tooltip: 'ওয়ার্ড সামারি দেখুন',
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
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('মাস নির্বাচন করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  MonthPickerField(month: _month, year: _year, onChanged: _onMonthChanged),
                  if (specialCriteria.isNotEmpty) ...[
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
                              const Expanded(
                                child: Text('আদায় / বকেয়া', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (hasTarget)
                                Text(
                                  'লক্ষ্যমাত্রা: ${CurrencyFormatter.format(widget.ward.targetAmount)}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...specialCriteria.map(_criteriaField),
                          if (hasTarget && anySpecialFilled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: (matched ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    matched ? Icons.check_circle_outline : Icons.info_outline,
                                    size: 18,
                                    color: matched ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      matched
                                          ? 'আদায় + বকেয়া লক্ষ্যমাত্রার সাথে মিলেছে'
                                          : 'আদায় + বকেয়া = ${CurrencyFormatter.format(specialSum)} '
                                              '— লক্ষ্যমাত্রা ${CurrencyFormatter.format(widget.ward.targetAmount)}',
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
                  const Text('অন্যান্য ক্রাইটেরিয়া (সবগুলো ঐচ্ছিক)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (normalCriteria.isEmpty)
                    const EmptyState(
                      icon: Icons.category_outlined,
                      message: 'এই প্রতিষ্ঠানের জন্য অতিরিক্ত কোনো ক্রাইটেরিয়া নেই।',
                    )
                  else
                    ...normalCriteria.map(_criteriaField),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: (_criteriaList.isEmpty || _saving) ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('সংরক্ষণ করুন'),
                  ),
                ],
              ),
            ),
    );
  }
}
