import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../db/database_helper.dart';
import '../utils/bangla_pdf_text.dart';
import '../utils/bangla_utils.dart';
import '../utils/currency_formatter.dart';

/// Generates the Ward × Criteria matrix report as a PDF (FR-8.7) with
/// Bangla labels, plus the higher-management remittance summary, shares it
/// via the Android share sheet (FR-8.9), and can open the native Android
/// print/preview dialog. Runs fully offline (FR-8.10).
///
/// All Bangla *label* text (title, ward/criteria names, headers) is
/// rasterized through [BanglaPdfText] rather than drawn as native PDF text
/// — see that class for why. Amounts stay as native, selectable text using
/// the bundled NotoSansBengali font (digits/punctuation never need glyph
/// reordering, but still need a font with full Unicode coverage — the
/// PDF's built-in Helvetica fallback is missing even the em dash "—").
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
    required double totalCollection,
    required double expenseAmount,
    required double actualDepositAmount,
  }) async {
    await _ensureFonts();
    final doc = pw.Document();

    final numberStyle = pw.TextStyle(fontSize: 10, font: _regular);
    final totalNumberStyle = pw.TextStyle(fontSize: 10, font: _bold, fontWeight: pw.FontWeight.bold);

    Future<pw.Widget> label(String text, {double fontSize = 10, bool bold = false}) {
      return BanglaPdfText.widget(text, fontSize: fontSize, bold: bold);
    }

    pw.Widget cell(pw.Widget child, {pw.Alignment alignment = pw.Alignment.centerRight}) {
      return pw.Container(
        alignment: alignment,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: child,
      );
    }

    final title = await label('বাইতুলমাল কালেকশন ট্র্যাকার', fontSize: 16, bold: true);
    // Em dash, not middle-dot: NotoSansBengali (and the test harness used to
    // verify this file's rendering) doesn't reliably have U+00B7.
    final subtitle = await label('$protisthanName — ${BanglaMonths.label(month, year)}', fontSize: 12);
    final footerNote = await label(
      'নিচের-ডানদিকের ঘর = ওয়ার্ড টোটালের যোগফল = ক্রাইটেরিয়া টোটালের যোগফল',
      fontSize: 9,
    );

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell(await label('ওয়ার্ড', bold: true), alignment: pw.Alignment.centerLeft),
        for (final c in data.criteriaList) cell(await label(c.name, bold: true)),
        cell(await label('মোট', bold: true)),
      ],
    );

    final wardRows = <pw.TableRow>[];
    for (final w in data.wards) {
      wardRows.add(
        pw.TableRow(
          children: [
            cell(await label(w.name), alignment: pw.Alignment.centerLeft),
            for (final c in data.criteriaList)
              cell(pw.Text(CurrencyFormatter.cellDisplay(data.amountFor(w.id!, c.id!)), style: numberStyle)),
            cell(pw.Text(
              CurrencyFormatter.format(data.rowTotals[w.id!] ?? 0, withSymbol: false),
              style: totalNumberStyle,
            )),
          ],
        ),
      );
    }

    final grandRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell(await label('সর্বমোট', bold: true), alignment: pw.Alignment.centerLeft),
        for (final c in data.criteriaList)
          cell(pw.Text(
            CurrencyFormatter.format(data.colTotals[c.id!] ?? 0, withSymbol: false),
            style: totalNumberStyle,
          )),
        cell(pw.Text(
          CurrencyFormatter.format(data.grandTotal, withSymbol: false),
          style: totalNumberStyle,
        )),
      ],
    );

    // Higher-management remittance summary (১ - ২ = ৩):
    //   ১. মোট কালেকশন (auto, from Entry data)
    //   ২. মোট খরচ (manually entered)
    //   ৩. প্রকৃত জমা (manually entered, actually deposited upward)
    final expectedDeposit = totalCollection - expenseAmount;
    final difference = actualDepositAmount - expectedDeposit;
    final matched = difference.abs() < 0.005;

    final remittanceHeading = await label('উচ্চ কর্তৃপক্ষে জমার হিসাব', fontSize: 13, bold: true);
    // No ৳ symbol here, matching the matrix table's own convention above —
    // package:pdf's native text also mis-renders that glyph, and the report
    // header/title already establishes these are all BDT amounts.
    final remittanceLabels = await Future.wait([
      label('১. মোট কালেকশন'),
      label('২. মোট খরচ'),
      label('প্রত্যাশিত জমা (১ - ২)', bold: true),
      label('৩. উচ্চ কর্তৃপক্ষে প্রকৃত জমা', bold: true),
      label(matched
          ? 'মিলেছে ✓'
          : 'অমিল — পার্থক্য ${CurrencyFormatter.format(difference.abs(), withSymbol: false)}'),
    ]);

    pw.Widget remittanceRow(pw.Widget labelWidget, double amount, {bool bold = false}) {
      final style = bold ? totalNumberStyle : numberStyle;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            labelWidget,
            pw.Text(CurrencyFormatter.format(amount, withSymbol: false), style: style),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          title,
          pw.SizedBox(height: 4),
          subtitle,
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [headerRow, ...wardRows, grandRow],
          ),
          pw.SizedBox(height: 12),
          footerNote,
          pw.SizedBox(height: 24),
          pw.Container(
            width: 280,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                remittanceHeading,
                pw.SizedBox(height: 8),
                remittanceRow(remittanceLabels[0], totalCollection),
                remittanceRow(remittanceLabels[1], expenseAmount),
                pw.Divider(color: PdfColors.grey400, height: 12),
                remittanceRow(remittanceLabels[2], expectedDeposit, bold: true),
                remittanceRow(remittanceLabels[3], actualDepositAmount, bold: true),
                pw.SizedBox(height: 6),
                remittanceLabels[4],
              ],
            ),
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
    required double totalCollection,
    required double expenseAmount,
    required double actualDepositAmount,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      totalCollection: totalCollection,
      expenseAmount: expenseAmount,
      actualDepositAmount: actualDepositAmount,
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: ReportFileName.build(
        protisthanName: protisthanName,
        month: month,
        year: year,
        extension: 'pdf',
      ),
    );
  }

  /// Test-only escape hatch to inspect the generated PDF bytes directly.
  @visibleForTesting
  static Future<void> dumpForTest({
    required String path,
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
    double totalCollection = 0,
    double expenseAmount = 0,
    double actualDepositAmount = 0,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      totalCollection: totalCollection,
      expenseAmount: expenseAmount,
      actualDepositAmount: actualDepositAmount,
    );
    await File(path).writeAsBytes(await doc.save());
  }

  /// Opens Android's native print/preview dialog for the report.
  static Future<void> previewAndPrint({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
    required double totalCollection,
    required double expenseAmount,
    required double actualDepositAmount,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      totalCollection: totalCollection,
      expenseAmount: expenseAmount,
      actualDepositAmount: actualDepositAmount,
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }
}
