import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../l10n/strings.dart';
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
  double _actualDepositTotal = 0;
  double _wardExpenseTotal = 0;
  double _protisthanExpenseAmount = 0;
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
    final wardActualDeposit = await db.getProtisthanActualDepositTotal(widget.protisthan.id!, _month, _year);
    final thanaActualDeposit = await db.getThanaActualDeposit(widget.protisthan.id!, _month, _year);
    final wardExpenseTotal = await db.getWardExpenseTotal(widget.protisthan.id!, _month, _year);
    final remittance = await db.getRemittance(widget.protisthan.id!, _month, _year);
    if (!mounted) return;
    setState(() {
      _data = data;
      // থানাসহ সকল ওয়ার্ডের বাস্তব জমা — real wards' যোগফল + থানার নিজস্ব আয়।
      _actualDepositTotal = wardActualDeposit + thanaActualDeposit;
      _wardExpenseTotal = wardExpenseTotal;
      _protisthanExpenseAmount = remittance?.expenseAmount ?? 0;
      _loading = false;
    });
  }

  Future<void> _exportPdf(Strings s) async {
    if (_data == null) return;
    setState(() => _exporting = true);
    try {
      await PdfExportService.generateAndShare(
        protisthanName: widget.protisthan.name,
        month: _month,
        year: _year,
        data: _data!,
        actualDepositTotal: _actualDepositTotal,
        wardExpenseTotal: _wardExpenseTotal,
        protisthanExpenseAmount: _protisthanExpenseAmount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pdfGenerateFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _printPreview(Strings s) async {
    if (_data == null) return;
    setState(() => _exporting = true);
    try {
      await PdfExportService.previewAndPrint(
        protisthanName: widget.protisthan.name,
        month: _month,
        year: _year,
        data: _data!,
        actualDepositTotal: _actualDepositTotal,
        wardExpenseTotal: _wardExpenseTotal,
        protisthanExpenseAmount: _protisthanExpenseAmount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.previewOpenFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel(Strings s) async {
    if (_data == null) return;
    setState(() => _exporting = true);
    try {
      await ExcelExportService.generateAndShare(
        protisthanName: widget.protisthan.name,
        month: _month,
        year: _year,
        data: _data!,
        actualDepositTotal: _actualDepositTotal,
        wardExpenseTotal: _wardExpenseTotal,
        protisthanExpenseAmount: _protisthanExpenseAmount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.excelGenerateFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final data = _data;
    const headerStyle = TextStyle(fontWeight: FontWeight.bold);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.matrixReportTitle(widget.protisthan.name)),
        actions: [
          IconButton(
            tooltip: s.printPreviewTooltip,
            icon: const Icon(Icons.print_outlined),
            onPressed: (_data == null || _exporting) ? null : () => _printPreview(s),
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
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    s.matrixNeedsWardAndCriteria,
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
                      DataColumn(label: Text(s.matrixColumnWard, style: headerStyle)),
                      ...data.criteriaList.map((c) => DataColumn(label: Text(c.name, style: headerStyle))),
                      DataColumn(label: Text(s.matrixColumnTotal, style: headerStyle)),
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
                          DataCell(Text(s.matrixRowGrandTotal, style: headerStyle)),
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
                      DataRow(cells: [
                        DataCell(Text(s.matrixRowThana)),
                        ...data.criteriaList.map(
                          (c) => DataCell(Text(
                            data.thanaRow.containsKey(c.id!)
                                ? CurrencyFormatter.cellDisplay(data.thanaAmountFor(c.id!))
                                : '',
                          )),
                        ),
                        DataCell(Text(
                          CurrencyFormatter.format(data.thanaRowTotal, withSymbol: false),
                          style: headerStyle,
                        )),
                      ]),
                      DataRow(
                        color: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        cells: [
                          DataCell(Text(s.matrixRowCombinedGrandTotal, style: headerStyle)),
                          ...data.criteriaList.map(
                            (c) => DataCell(Text(
                              CurrencyFormatter.format(data.combinedColTotals[c.id!] ?? 0, withSymbol: false),
                              style: headerStyle,
                            )),
                          ),
                          DataCell(Text(
                            CurrencyFormatter.format(data.combinedGrandTotal, withSymbol: false),
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
                      label: Text(s.pdfDownloadButton),
                      onPressed: (data == null || _exporting) ? null : () => _exportPdf(s),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.grid_on_outlined),
                      label: Text(s.excelDownloadButton),
                      onPressed: (data == null || _exporting) ? null : () => _exportExcel(s),
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
