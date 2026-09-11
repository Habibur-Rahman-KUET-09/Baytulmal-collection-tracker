import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../utils/currency_formatter.dart';
import '../widgets/month_picker_field.dart';

/// Screen 7: প্রতিষ্ঠান মাসিক সামারি — FR-6.1, FR-5.4, FR-5.5.
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

  double _total = 0;
  double _targetTotal = 0;
  List<MapEntry<Criteria, double>> _criteriaBreakdown = [];
  List<MapEntry<Ward, double>> _wardBreakdown = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _month = now.month;
    _year = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final total = await db.getProtisthanTotal(widget.protisthan.id!, _month, _year);
    final criteriaBreakdown =
        await db.getProtisthanCriteriaBreakdown(widget.protisthan.id!, _month, _year);
    final wardBreakdown = await db.getProtisthanWardBreakdown(widget.protisthan.id!, _month, _year);
    final targetTotal = await db.getProtisthanTargetTotal(widget.protisthan.id!);
    if (!mounted) return;
    setState(() {
      _total = total;
      _criteriaBreakdown = criteriaBreakdown;
      _wardBreakdown = wardBreakdown;
      _targetTotal = targetTotal;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('মাসিক সামারি')),
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
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Text(
                          CurrencyFormatter.format(_total),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('মোট কালেকশন'),
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
                        const Text('সকল ওয়ার্ডের মোট নির্ধারিত লক্ষ্যমাত্রা', style: TextStyle(fontSize: 12.5)),
                        Text(
                          CurrencyFormatter.format(_targetTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('ক্রাইটেরিয়া অনুযায়ী', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ..._criteriaBreakdown.map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key.name),
                    trailing: Text(CurrencyFormatter.format(e.value)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('ওয়ার্ড অনুযায়ী', style: TextStyle(fontWeight: FontWeight.bold)),
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
