import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/protisthan.dart';
import '../utils/currency_formatter.dart';
import '../widgets/month_picker_field.dart';

/// উচ্চ কর্তৃপক্ষে জমার হিসাব — a separate, per-Protisthan/month page
/// tracking how much of this Protisthan's collection was actually
/// remitted upward: ১. মোট কালেকশন (auto) − ২. মোট খরচ (manual) should
/// equal ৩. প্রকৃত জমা (manual, the real recorded deposit).
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

  double _totalCollection = 0;
  final _expenseCtrl = TextEditingController();
  final _actualCtrl = TextEditingController();
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
    _actualCtrl.dispose();
    super.dispose();
  }

  String _trimZero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _load() async {
    setState(() => _loading = true);
    final total = await db.getProtisthanTotal(widget.protisthan.id!, _month, _year);
    final remittance = await db.getRemittance(widget.protisthan.id!, _month, _year);
    if (!mounted) return;
    setState(() {
      _totalCollection = total;
      _expenseCtrl.text = remittance == null || remittance.expenseAmount == 0
          ? ''
          : _trimZero(remittance.expenseAmount);
      _actualCtrl.text = remittance == null || remittance.actualDepositAmount == 0
          ? ''
          : _trimZero(remittance.actualDepositAmount);
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
        actualDepositAmount: double.tryParse(_actualCtrl.text.trim()) ?? 0,
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
    final actual = double.tryParse(_actualCtrl.text.trim()) ?? 0;
    final expected = _totalCollection - expense;
    final difference = actual - expected;
    final hasActual = _actualCtrl.text.trim().isNotEmpty;
    final matched = difference.abs() < 0.005;

    return Scaffold(
      appBar: AppBar(title: Text('উচ্চ কর্তৃপক্ষে জমা (${widget.protisthan.name})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
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
                _StatRow(label: '১. মোট কালেকশন', value: CurrencyFormatter.format(_totalCollection)),
                const SizedBox(height: 14),
                TextField(
                  controller: _expenseCtrl,
                  decoration: const InputDecoration(
                    labelText: '২. মোট খরচ (৳)',
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
                _StatRow(label: 'প্রত্যাশিত জমা (১ - ২)', value: CurrencyFormatter.format(expected), bold: true),
                const SizedBox(height: 14),
                TextField(
                  controller: _actualCtrl,
                  decoration: const InputDecoration(
                    labelText: '৩. উচ্চ কর্তৃপক্ষে প্রকৃত জমা (৳)',
                    helperText: 'বাস্তবে যত টাকা জমা দেওয়া হয়েছে',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  onChanged: (_) => setState(() {}),
                ),
                if (hasActual) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (matched ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: matched ? Colors.green : Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          matched ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                          color: matched ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            matched
                                ? 'প্রত্যাশিত জমার সাথে মিলেছে'
                                : 'অমিল — পার্থক্য ${CurrencyFormatter.format(difference.abs())}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
