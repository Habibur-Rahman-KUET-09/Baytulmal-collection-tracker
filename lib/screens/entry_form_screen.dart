import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../providers/app_data_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/month_picker_field.dart';
import 'ward_summary_screen.dart';

/// Screen 6: ডেটা এন্ট্রি ফর্ম — FR-4.1 .. FR-4.6.
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

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 20),
                  const Text('ক্রাইটেরিয়া (সবগুলো ঐচ্ছিক)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_criteriaList.isEmpty)
                    const EmptyState(
                      icon: Icons.category_outlined,
                      message:
                          'এই প্রতিষ্ঠানের জন্য কোনো ক্রাইটেরিয়া নির্ধারিত নেই।\nপ্রথমে ক্রাইটেরিয়া যোগ করুন।',
                    )
                  else
                    ..._criteriaList.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _controllers[c.id!],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            decoration: InputDecoration(
                              labelText: '${c.name} (৳)',
                              hintText: 'খালি',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null) return 'সঠিক সংখ্যা দিন';
                              if (parsed < 0) return 'ঋণাত্মক মান গ্রহণযোগ্য নয়';
                              return null;
                            },
                          ),
                        )),
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
