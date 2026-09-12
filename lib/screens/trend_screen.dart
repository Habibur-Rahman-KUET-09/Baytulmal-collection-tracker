import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/criteria.dart';
import '../models/protisthan.dart';
import '../models/ward.dart';
import '../utils/bangla_utils.dart';
import '../utils/currency_formatter.dart';
import '../utils/safe_padding.dart';
import '../widgets/month_picker_field.dart';

enum _TrendMode { total, criteria, ward }

/// Screen 9: ট্রেন্ড/তুলনা — FR-6.3, FR-6.4.
class TrendScreen extends StatefulWidget {
  final Protisthan protisthan;
  const TrendScreen({super.key, required this.protisthan});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  final db = DatabaseHelper.instance;
  final now = DateTime.now();

  late int _startMonth;
  late int _startYear;
  late int _endMonth;
  late int _endYear;

  _TrendMode _mode = _TrendMode.total;
  int? _selectedCriteriaId;
  int? _selectedWardId;

  List<Criteria> _criteriaList = [];
  List<Ward> _wardList = [];
  List<TrendPoint> _points = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _endMonth = now.month;
    _endYear = now.year;
    final start = DateTime(now.year, now.month - 5);
    _startMonth = start.month;
    _startYear = start.year;
    _init();
  }

  Future<void> _init() async {
    final criteriaList = await db.getCriteriaForProtisthan(widget.protisthan.id!);
    // ধার্যকৃত নিসাব ও বাস্তব জমার কোনো Entry নেই (দুটোই সবসময় হিসাব করে
    // দেখানো হয়), তাই ট্রেন্ড হিসেবে বেছে নিলে সবসময় ০-ই দেখাবে — তাই এই
    // দুটো এখানে বেছে নেওয়ার অপশন হিসেবে রাখা হচ্ছে না।
    _criteriaList = criteriaList.where((c) => !c.hasNoEntry).toList();
    _wardList = await db.getWardsForProtisthan(widget.protisthan.id!);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final points = await db.getTrendData(
      protisthanId: widget.protisthan.id!,
      startMonth: _startMonth,
      startYear: _startYear,
      endMonth: _endMonth,
      endYear: _endYear,
      criteriaId: _mode == _TrendMode.criteria ? _selectedCriteriaId : null,
      wardId: _mode == _TrendMode.ward ? _selectedWardId : null,
    );
    if (!mounted) return;
    setState(() {
      _points = points;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxPoint = _points.isEmpty
        ? null
        : _points.reduce((a, b) => a.total >= b.total ? a : b);
    final maxY = _points.isEmpty
        ? 100.0
        : (_points.map((p) => p.total).reduce((a, b) => a > b ? a : b)) * 1.2;

    return Scaffold(
      appBar: AppBar(title: const Text('ট্রেন্ড দেখুন')),
      body: Padding(
        padding: safeBodyPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('মোট কালেকশন'),
                  selected: _mode == _TrendMode.total,
                  onSelected: (_) {
                    setState(() => _mode = _TrendMode.total);
                    _load();
                  },
                ),
                ..._criteriaList.map(
                  (c) => ChoiceChip(
                    label: Text(c.name),
                    selected: _mode == _TrendMode.criteria && _selectedCriteriaId == c.id,
                    onSelected: (_) {
                      setState(() {
                        _mode = _TrendMode.criteria;
                        _selectedCriteriaId = c.id;
                      });
                      _load();
                    },
                  ),
                ),
                ..._wardList.map(
                  (w) => ChoiceChip(
                    label: Text(w.name),
                    selected: _mode == _TrendMode.ward && _selectedWardId == w.id,
                    onSelected: (_) {
                      setState(() {
                        _mode = _TrendMode.ward;
                        _selectedWardId = w.id;
                      });
                      _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MonthPickerField(
                    month: _startMonth,
                    year: _startYear,
                    onChanged: (d) {
                      setState(() {
                        _startMonth = d.month;
                        _startYear = d.year;
                      });
                      _load();
                    },
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—')),
                Expanded(
                  child: MonthPickerField(
                    month: _endMonth,
                    year: _endYear,
                    onChanged: (d) {
                      setState(() {
                        _endMonth = d.month;
                        _endYear = d.year;
                      });
                      _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _points.isEmpty
                      ? const Center(child: Text('কোনো তথ্য পাওয়া যায়নি'))
                      : BarChart(
                          BarChartData(
                            maxY: maxY == 0 ? 100 : maxY,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final p = _points[groupIndex];
                                  return BarTooltipItem(
                                    CurrencyFormatter.format(p.total),
                                    const TextStyle(color: Colors.white),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= _points.length) return const SizedBox.shrink();
                                    final p = _points[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        BanglaMonths.shortLabel(p.month, p.year),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              for (int i = 0; i < _points.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: _points[i].total,
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 16,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
            ),
            if (maxPoint != null && maxPoint.total > 0) ...[
              const SizedBox(height: 12),
              Text(
                'সর্বোচ্চ মাস: ${BanglaMonths.label(maxPoint.month, maxPoint.year)} '
                '(${CurrencyFormatter.format(maxPoint.total)})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
