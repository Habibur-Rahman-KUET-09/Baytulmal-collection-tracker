import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../db/database_helper.dart';
import '../utils/bangla_utils.dart';
import '../utils/currency_formatter.dart';

/// Generates the Ward × Criteria matrix report as a PDF (FR-8.7) with
/// Bangla labels, shares it via the Android share sheet (FR-8.9), and can
/// open the native Android print/preview dialog. Runs fully offline
/// (FR-8.10) — the Bangla font is bundled as an asset.
class PdfExportService {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf'));
  }

  static Future<pw.Document> _buildDocument({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
  }) async {
    await _ensureFonts();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
    );

    final headers = ['ওয়ার্ড', ...data.criteriaList.map((c) => c.name), 'মোট'];
    final rows = <List<String>>[
      for (final w in data.wards)
        [
          w.name,
          ...data.criteriaList.map((c) => CurrencyFormatter.cellDisplay(data.amountFor(w.id!, c.id!))),
          CurrencyFormatter.format(data.rowTotals[w.id!] ?? 0, withSymbol: false),
        ],
      [
        'সর্বমোট',
        ...data.criteriaList.map((c) => CurrencyFormatter.format(data.colTotals[c.id!] ?? 0, withSymbol: false)),
        CurrencyFormatter.format(data.grandTotal, withSymbol: false),
      ],
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Text(
            'বাইতুলমাল কালেকশন ট্র্যাকার — ম্যাট্রিক্স রিপোর্ট',
            style: pw.TextStyle(font: _bold, fontSize: 16),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$protisthanName · ${BanglaMonths.label(month, year)}',
            style: pw.TextStyle(font: _regular, fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(font: _bold, fontSize: 10),
            cellStyle: pw.TextStyle(font: _regular, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
            cellAlignments: {0: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'নিচের-ডানদিকের ঘর = ওয়ার্ড টোটালের যোগফল = ক্রাইটেরিয়া টোটালের যোগফল',
            style: pw.TextStyle(font: _regular, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc;
  }

  /// Shares the PDF via the Android share sheet (FR-8.9) using the
  /// `printing` package's native share, so no separate file-sharing plugin
  /// is needed for this format.
  static Future<void> generateAndShare({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
    );
    final safeName = protisthanName.replaceAll(RegExp(r'[^\wঀ-৿]+'), '_');
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'matrix_report_${safeName}_${year}_$month.pdf',
    );
  }

  /// Opens Android's native print/preview dialog for the report.
  static Future<void> previewAndPrint({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }
}
