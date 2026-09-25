import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
import '../models/membership.dart';
import '../models/protisthan.dart';
import '../providers/app_data_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../widgets/month_picker_field.dart';
import '../utils/number_input.dart';

/// থানার বাস্তব জমা খরচ — a separate, per-Protisthan/month page tracking how
/// much of this Protisthan's collection was actually remitted upward:
/// ১. থানাসহ সকল ওয়ার্ডের বাস্তব জমা (auto = sum of all real wards' আয়−ব্যয়
/// PLUS থানার নিজস্ব আয়/বাস্তব জমা, see [DatabaseHelper.getThanaActualDeposit])
/// − ২. থানার ব্যয় (manual) gives "থানার নিসাব", which is always computed,
/// not typed.
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


  Future<void> _load() async {
    setState(() => _loading = true);
    final wardTotal = await db.getProtisthanActualDepositTotal(widget.protisthan.id!, _month, _year);
    final thanaDeposit = await db.getThanaActualDeposit(widget.protisthan.id!, _month, _year);
    final remittance = await db.getRemittance(widget.protisthan.id!, _month, _year);
    if (!mounted) return;
    setState(() {
      _actualDepositTotal = wardTotal + thanaDeposit;
      _expenseCtrl.text = remittance == null || remittance.expenseAmount == 0
          ? ''
          : NumberInput.editable(remittance.expenseAmount);
      _existingActualDepositAmount = remittance?.actualDepositAmount ?? 0;
      _loading = false;
    });
  }

  Future<void> _save(Strings s) async {
    setState(() => _saving = true);
    try {
      await context.read<AppDataProvider>().saveRemittance(
            protisthan: widget.protisthan,
            month: _month,
            year: _year,
            expenseAmount: NumberInput.parse(_expenseCtrl.text) ?? 0,
            actualDepositAmount: _existingActualDepositAmount,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.savedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final role = context.watch<AppDataProvider>().roleFor(widget.protisthan);
    final canEnter = role?.canEnterData ?? false;
    final expense = NumberInput.parse(_expenseCtrl.text) ?? 0;
    final thanaNisab = _actualDepositTotal - expense;

    return Scaffold(
      appBar: AppBar(title: Text(s.remittanceTitle(widget.protisthan.name))),
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
                  label: s.remittanceRow1Label,
                  value: CurrencyFormatter.format(_actualDepositTotal),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _expenseCtrl,
                  enabled: canEnter,
                  decoration: InputDecoration(
                    labelText: s.remittanceExpenseLabel,
                    helperText: s.remittanceExpenseHelper,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: NumberInput.formatters,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 4),
                _StatRow(
                  label: s.remittanceNisabRowLabel,
                  value: CurrencyFormatter.format(thanaNisab),
                  bold: true,
                ),
                const SizedBox(height: 24),
                if (canEnter)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(s),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(s.save),
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
