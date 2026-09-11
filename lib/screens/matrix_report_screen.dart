import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/protisthan.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/currency_formatter.dart';
import '../widgets/month_picker_field.dart';

/// Screen 10: ম্যাট্রিক্স রিপোর্ট (Ward × Criteria) — Preview + Export.
/// FR-8.1 .. FR-8.10.
class MatrixReportScreen extends StatefulWidget {
  final Protisthan protisthan;
  const MatrixReportScreen({super.key, required this.protisthan});

  @override
  State<MatrixReportScreen> createState() => _MatrixReportScreenState();
}

class _MatrixReportScreenState extends State<MatrixReportScreen> {
  final db = DatabaseHelper.instance;
  final now = DateTime.now();
  late int _month;
  late int _year;
  MatrixReportData? _data;
  double _totalCollection = 0;
  double _expenseAmount = 0;
  double _actualDepositAmount = 0;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _month = now.month;
    _year = now.year;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await db.getMatrixReport(widget.protisthan.id!, _month, _year);
    final total = await db.getProtisthanTotal(widget.protisthan.id!, _month, _year);
    final remittance = await db.getRemittance(widget.protisthan.id!, _month, _year);
    if (!mounted) return;
    setState(() {
      _data = data;
      _totalCollection = total;
      _expenseAmount = remittance?.expenseAmount ?? 0;
      _actualDepositAmount = remittance?.actualDepositAmount ?? 0;
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    if (_data == null) return;
    setState(() => _exporting = true);
    try {
      await PdfExportService.generateAndShare(
        protisthanName: widget.protisthan.name,
        month: _month,
        year: _year,
        data: _data!,
        totalCollection: _totalCollection,
        expenseAmount: _expenseAmount,
        actualDepositAmount: _actualDepositAmount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF তৈরি করা যায়নি: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printPreview() async {
    if (_data == null) return;
    setState(() => _exporting = true);
    try {
      await PdfExportService.previewAndPrint(
        protisthanName: widget.protisthan.name,
        month: _month,
        year: _year,
        data: _data!,
        totalCollection: _totalCollection,
        expenseAmount: _expenseAmount,
        actualDepositAmount: _actualDepositAmount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('প্রিভিউ খোলা যায়নি: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_data == null) return;
    setState(() => _exporting = true);
    try {
      await ExcelExportService.generateAndShare(
        protisthanName: widget.protisthan.name,
        month: _month,
        year: _year,
        data: _data!,
        totalCollection: _totalCollection,
        expenseAmount: _expenseAmount,
        actualDepositAmount: _actualDepositAmount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Excel তৈরি করা যায়নি: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    const headerStyle = TextStyle(fontWeight: FontWeight.bold);
    return Scaffold(
      appBar: AppBar(
        title: Text('রিপোর্ট — ${widget.protisthan.name}'),
        actions: [
          IconButton(
            tooltip: 'প্রিন্ট / প্রিভিউ',
            icon: const Icon(Icons.print_outlined),
            onPressed: (_data == null || _exporting) ? null : _printPreview,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: MonthPickerField(
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
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (data == null || (data.wards.isEmpty || data.criteriaList.isEmpty))
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'রিপোর্ট তৈরি করতে অন্তত একটি ওয়ার্ড এবং একটি ক্রাইটেরিয়া প্রয়োজন।',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    columns: [
                      DataColumn(label: Text('ওয়ার্ড', style: headerStyle)),
                      ...data.criteriaList.map((c) => DataColumn(label: Text(c.name, style: headerStyle))),
                      DataColumn(label: Text('মোট', style: headerStyle)),
                    ],
                    rows: [
                      for (final w in data.wards)
                        DataRow(cells: [
                          DataCell(Text(w.name)),
                          ...data.criteriaList.map(
                            (c) => DataCell(Text(CurrencyFormatter.cellDisplay(data.amountFor(w.id!, c.id!)))),
                          ),
                          DataCell(Text(
                            CurrencyFormatter.format(data.rowTotals[w.id!] ?? 0, withSymbol: false),
                            style: headerStyle,
                          )),
                        ]),
                      DataRow(
                        color: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        cells: [
                          DataCell(Text('সর্বমোট', style: headerStyle)),
                          ...data.criteriaList.map(
                            (c) => DataCell(Text(
                              CurrencyFormatter.format(data.colTotals[c.id!] ?? 0, withSymbol: false),
                              style: headerStyle,
                            )),
                          ),
                          DataCell(Text(
                            CurrencyFormatter.format(data.grandTotal, withSymbol: false),
                            style: headerStyle,
                          )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF ডাউনলোড'),
                      onPressed: (data == null || _exporting) ? null : _exportPdf,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.grid_on_outlined),
                      label: const Text('Excel ডাউনলোড'),
                      onPressed: (data == null || _exporting) ? null : _exportExcel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
