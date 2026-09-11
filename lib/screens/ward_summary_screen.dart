import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../utils/currency_formatter.dart';
import '../widgets/month_picker_field.dart';

/// Screen 8: ওয়ার্ড মাসিক সামারি — FR-6.2, FR-5.2.
class WardSummaryScreen extends StatefulWidget {
  final Ward ward;
  final Protisthan protisthan;
  final int initialMonth;
  final int initialYear;

  const WardSummaryScreen({
    super.key,
    required this.ward,
    required this.protisthan,
    required this.initialMonth,
    required this.initialYear,
  });

  @override
  State<WardSummaryScreen> createState() => _WardSummaryScreenState();
}

class _WardSummaryScreenState extends State<WardSummaryScreen> {
  final db = DatabaseHelper.instance;
  late int _month;
  late int _year;
  double _total = 0;
  List<MapEntry<Criteria, double>> _breakdown = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final total = await db.getWardTotal(widget.ward.id!, _month, _year);
    final breakdown = await db.getWardCriteriaBreakdown(
      widget.ward.id!,
      widget.protisthan.id!,
      _month,
      _year,
    );
    if (!mounted) return;
    setState(() {
      _total = total;
      _breakdown = breakdown;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.ward.name} — সামারি')),
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
                        Text('${widget.ward.name}-এর মোট'),
                      ],
                    ),
                  ),
                ),
                if (widget.ward.targetAmount > 0) ...[
                  const SizedBox(height: 12),
                  _TargetMatchCard(target: widget.ward.targetAmount, breakdown: _breakdown),
                ],
                const SizedBox(height: 20),
                const Text('ক্রাইটেরিয়া অনুযায়ী বিভাজন', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._breakdown.map(
                  (e) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(e.key.name),
                      trailing: Text(
                        e.value == 0 ? '—' : CurrencyFormatter.format(e.value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TargetMatchCard extends StatelessWidget {
  final double target;
  final List<MapEntry<Criteria, double>> breakdown;
  const _TargetMatchCard({required this.target, required this.breakdown});

  double _sumOf(int specialOrder) {
    final entry = breakdown.where((e) => e.key.specialOrder == specialOrder);
    return entry.isEmpty ? 0 : entry.first.value;
  }

  @override
  Widget build(BuildContext context) {
    final specialSum = _sumOf(2) + _sumOf(3);
    final matched = (specialSum - target).abs() < 0.005;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (matched ? Colors.green : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: matched ? Colors.green : Colors.orange),
      ),
      child: Row(
        children: [
          Icon(
            matched ? Icons.check_circle_outline : Icons.info_outline,
            color: matched ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'নির্ধারিত লক্ষ্যমাত্রা: ${CurrencyFormatter.format(target)}'
              '${matched ? ' — আদায়+বকেয়ার সাথে মিলেছে' : ' — আদায়+বকেয়া: ${CurrencyFormatter.format(specialSum)}'}',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
