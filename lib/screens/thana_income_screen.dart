import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../providers/app_data_provider.dart';
import '../utils/safe_padding.dart';
import '../widgets/empty_state.dart';
import '../widgets/month_picker_field.dart';

/// থানার আয় — থানার নিজস্ব প্রত্যক্ষ কালেকশন, খাত (normal criteria) অনুযায়ী।
/// এখানে কোনো নিসাব/আয়/ব্যয়/বাস্তব জমা সেকশন নেই — থানার ব্যয় আলাদাভাবে
/// "থানার বাস্তব জমা খরচ" পাতায় টাইপ করা হয়, আর থানার বাস্তব জমা ওয়ার্ডের
/// মতোই ম্যাট্রিক্স রিপোর্টে অটো-ক্যালকুলেট হয় (থানা রো = এই স্ক্রিনের
/// ইনপুটগুলোর যোগফল)। সংরক্ষণ হয় প্রতিষ্ঠানের হিডেন ভার্চুয়াল থানা-ওয়ার্ডের
/// বিপরীতে (দেখুন [DatabaseHelper.getThanaWard]), যাতে ওয়ার্ড/এন্ট্রি সংক্রান্ত
/// বিদ্যমান মেশিনারি পুনঃব্যবহার করা যায়।
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
  int? _thanaWardId;
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
    final existing = thanaWard == null
        ? <int, double>{}
        : await db.getEntriesForWardMonth(thanaWard.id!, _month, _year);

    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final c in normalCriteria) {
      final value = existing[c.id];
      _controllers[c.id!] = TextEditingController(
        text: value == null ? '' : _trimZero(value),
      );
    }

    if (!mounted) return;
    setState(() {
      _thanaWardId = thanaWard?.id;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_thanaWardId == null) return;
    setState(() => _saving = true);
    final appData = context.read<AppDataProvider>();
    try {
      for (final c in _normalCriteria) {
        final text = _controllers[c.id!]!.text.trim();
        final amount = text.isEmpty ? null : double.parse(text);
        await db.saveEntry(
          wardId: _thanaWardId!,
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
    return Scaffold(
      appBar: AppBar(title: const Text('থানার আয়')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: safeBodyPadding(context),
                children: [
                  const Text('মাস নির্বাচন করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  MonthPickerField(month: _month, year: _year, onChanged: _onMonthChanged),
                  const SizedBox(height: 20),
                  const Text(
                    'খাত অনুযায়ী থানার আয় (সবগুলো ঐচ্ছিক)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_normalCriteria.isEmpty)
                    const EmptyState(
                      icon: Icons.category_outlined,
                      message: 'এই থানার জন্য কোনো খাত নেই।',
                    )
                  else
                    ..._normalCriteria.map(_criteriaField),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: (_normalCriteria.isEmpty || _saving) ? null : _save,
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
