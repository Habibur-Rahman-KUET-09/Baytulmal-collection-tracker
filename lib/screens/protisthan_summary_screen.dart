import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../widgets/month_picker_field.dart';

/// Screen 7: থানার মাসিক কালেকশন এক নজরে — FR-6.1, FR-5.4, FR-5.5.
///
/// তিনটি ধাপে যোগফল দেখায়: (ক) সকল ওয়ার্ডের মোট কালেকশন [ward-only, আগের
/// মতোই], (খ) + থানার আয় = উপ-যোগফল, (গ) − থানার ব্যয় = চূড়ান্ত যোগফল।
class ProtisthanSummaryScreen extends StatefulWidget {
  final Protisthan protisthan;
  const ProtisthanSummaryScreen({super.key, required this.protisthan});

  @override
  State<ProtisthanSummaryScreen> createState() => _ProtisthanSummaryScreenState();
}

class _ProtisthanSummaryScreenState extends State<ProtisthanSummaryScreen> {
  final db = DatabaseHelper.instance;
  final now = DateTime.now();
  late int _month;
  late int _year;

  double _wardTotal = 0;
  double _thanaIncome = 0;
  double _thanaExpense = 0;
  double _targetTotal = 0;
  List<MapEntry<Criteria, double>> _criteriaBreakdown = [];
  List<MapEntry<Ward, double>> _wardBreakdown = [];
  bool _loading = true;

  double get _subtotal => _wardTotal + _thanaIncome;
  double get _finalTotal => _subtotal - _thanaExpense;

  @override
  void initState() {
    super.initState();
    _month = now.month;
    _year = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final wardTotal = await db.getProtisthanTotal(widget.protisthan.id!, _month, _year);
    final thanaIncome = await db.getThanaIncomeTotal(widget.protisthan.id!, _month, _year);
    final remittance = await db.getRemittance(widget.protisthan.id!, _month, _year);
    final criteriaBreakdown =
        await db.getProtisthanCriteriaBreakdown(widget.protisthan.id!, _month, _year);
    final wardBreakdown = await db.getProtisthanWardBreakdown(widget.protisthan.id!, _month, _year);
    final targetTotal = await db.getProtisthanTargetTotal(widget.protisthan.id!);
    if (!mounted) return;
    setState(() {
      _wardTotal = wardTotal;
      _thanaIncome = thanaIncome;
      _thanaExpense = remittance?.expenseAmount ?? 0;
      _criteriaBreakdown = criteriaBreakdown;
      _wardBreakdown = wardBreakdown;
      _targetTotal = targetTotal;
      _loading = false;
    });
  }

  Widget _statRow(String label, double value, {bool bold = false, bool divider = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: divider
          ? const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12)))
          : null,
      margin: divider ? const EdgeInsets.only(top: 6) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            CurrencyFormatter.format(value),
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.protisthanSummaryTitle)),
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
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Text(
                          CurrencyFormatter.format(_finalTotal),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(s.totalCollectionLabel),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        _statRow(s.allWardsTotalLabel, _wardTotal),
                        _statRow(s.plusThanaIncomeLabel, _thanaIncome),
                        _statRow(s.subtotalLabel, _subtotal, bold: true, divider: true),
                        _statRow(s.minusThanaExpenseLabel, _thanaExpense),
                        _statRow(s.finalTotalLabel, _finalTotal, bold: true, divider: true),
                      ],
                    ),
                  ),
                ),
                if (_targetTotal > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.allWardsTargetLabel, style: const TextStyle(fontSize: 12.5)),
                        Text(
                          CurrencyFormatter.format(_targetTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(s.byCriteriaLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ..._criteriaBreakdown.map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key.name),
                    trailing: Text(CurrencyFormatter.format(e.value)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(s.byWardLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ..._wardBreakdown.map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key.name),
                    trailing: Text(CurrencyFormatter.format(e.value)),
                  ),
                ),
              ],
            ),
    );
  }
}
