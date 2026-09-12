import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/protisthan.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../widgets/month_picker_field.dart';

/// থানার বাস্তব জমা খরচ — a separate, per-Protisthan/month page tracking how
/// much of this Protisthan's collection was actually remitted upward:
/// ১. থানাসহ সকল ওয়ার্ডের বাস্তব জমা (auto, = sum of all wards' আয়−ব্যয়) −
/// ২. থানার ব্যয় (manual) gives "থানার বাস্তব জমা", which is always
/// computed, not typed.
class RemittanceScreen extends StatefulWidget {
  final Protisthan protisthan;
  const RemittanceScreen({super.key, required this.protisthan});

  @override
  State<RemittanceScreen> createState() => _RemittanceScreenState();
}

class _RemittanceScreenState extends State<RemittanceScreen> {
  final db = DatabaseHelper.instance;
  final now = DateTime.now();
  late int _month;
  late int _year;

  double _actualDepositTotal = 0;
  final _expenseCtrl = TextEditingController();
  // এই স্ক্রিন থেকে আর দেখানো/এডিট করা হয় না, কিন্তু আগে কেউ হাতে টাইপ করে
  // থাকলে সেই পুরনো মান সেভের সময় মুছে না ফেলে অপরিবর্তিত রেখে দেওয়া হয়।
  double _existingActualDepositAmount = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _month = now.month;
    _year = now.year;
    _load();
  }

  @override
  void dispose() {
    _expenseCtrl.dispose();
    super.dispose();
  }

  String _trimZero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _load() async {
    setState(() => _loading = true);
    final total = await db.getProtisthanActualDepositTotal(widget.protisthan.id!, _month, _year);
    final remittance = await db.getRemittance(widget.protisthan.id!, _month, _year);
    if (!mounted) return;
    setState(() {
      _actualDepositTotal = total;
      _expenseCtrl.text = remittance == null || remittance.expenseAmount == 0
          ? ''
          : _trimZero(remittance.expenseAmount);
      _existingActualDepositAmount = remittance?.actualDepositAmount ?? 0;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await db.saveRemittance(
        protisthanId: widget.protisthan.id!,
        month: _month,
        year: _year,
        expenseAmount: double.tryParse(_expenseCtrl.text.trim()) ?? 0,
        actualDepositAmount: _existingActualDepositAmount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সংরক্ষণ করা হয়েছে')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = double.tryParse(_expenseCtrl.text.trim()) ?? 0;
    final protisthanActualDeposit = _actualDepositTotal - expense;

    return Scaffold(
      appBar: AppBar(title: Text('থানার বাস্তব জমা খরচ (${widget.protisthan.name})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: safeBodyPadding(context),
              children: [
                MonthPickerField(
                  month: _month,
                  year: _year,
                  onChanged: (d) {
                    setState(() {
                      _month = d.month;
                      _year = d.year;
                    });
                    _load();
                  },
                ),
                const SizedBox(height: 20),
                _StatRow(
                  label: '১. থানাসহ সকল ওয়ার্ডের বাস্তব জমা',
                  value: CurrencyFormatter.format(_actualDepositTotal),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _expenseCtrl,
                  decoration: const InputDecoration(
                    labelText: '২. থানার ব্যয় (৳)',
                    helperText: 'ঐচ্ছিক — খালি রাখলে ০ ধরা হবে',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 4),
                _StatRow(
                  label: 'থানার বাস্তব জমা (১ - ২)',
                  value: CurrencyFormatter.format(protisthanActualDeposit),
                  bold: true,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('সংরক্ষণ করুন'),
                ),
              ],
            ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _StatRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
