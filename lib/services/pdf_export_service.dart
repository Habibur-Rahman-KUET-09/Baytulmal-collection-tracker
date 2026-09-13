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
    required double actualDepositTotal,
    required double wardExpenseTotal,
    required double protisthanExpenseAmount,
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
      'নিচের-ডানদিকের ঘর = ওয়ার্ড টোটালের যোগফল = খাত টোটালের যোগফল '
      '(ধার্যকৃত নিসাব ও আয় বাদে — এই দুটো তুলনার জন্য দেখানো হয়েছে, আয়ের হিসাব '
      'ব্যয় ও বাস্তব জমার মধ্য দিয়েই মোটে যুক্ত হয়ে যায়)',
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

    // থানার নিজস্ব normal-খাত কালেকশন (থানার আয়) + নিসাব(১, থানা তৈরির সময়
    // ফিক্সড)/আয়(২, ম্যানুয়াল)/বাস্তব জমা(৪, অটো=আয়) — শুধু ব্যয়(৩) খালি
    // থাকে, যেহেতু থানার ব্যয় এখানে কখনো এন্ট্রি হয় না।
    final thanaRowWidget = pw.TableRow(
      children: [
        cell(await label('থানা'), alignment: pw.Alignment.centerLeft),
        for (final c in data.criteriaList)
          cell(pw.Text(
            data.thanaRow.containsKey(c.id!) ? CurrencyFormatter.cellDisplay(data.thanaAmountFor(c.id!)) : '',
            style: numberStyle,
          )),
        cell(pw.Text(
          CurrencyFormatter.format(data.thanaRowTotal, withSymbol: false),
          style: totalNumberStyle,
        )),
      ],
    );

    final combinedGrandRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell(await label('থানাসহ সর্বমোট', bold: true), alignment: pw.Alignment.centerLeft),
        for (final c in data.criteriaList)
          cell(pw.Text(
            CurrencyFormatter.format(data.combinedColTotals[c.id!] ?? 0, withSymbol: false),
            style: totalNumberStyle,
          )),
        cell(pw.Text(
          CurrencyFormatter.format(data.combinedGrandTotal, withSymbol: false),
          style: totalNumberStyle,
        )),
      ],
    );

    // উচ্চ কর্তৃপক্ষে জমার হিসাব (১ - ২ = "থানার নিসাব", always computed —
    // no separate manually-typed figure to cross-check anymore):
    //   ১. থানাসহ সকল ওয়ার্ডের বাস্তব জমা (auto — real wards' আয়−ব্যয় +
    //      থানার নিজস্ব আয়/বাস্তব জমা)
    //   ২. থানার ব্যয় (manually entered)
    final thanaNisab = actualDepositTotal - protisthanExpenseAmount;

    // দুইটা বক্সের শেয়ার্ড হেডিং — নিচের বক্স-রো তে বসে, দুইটার আলাদা কোনো
    // হেডিং নেই (ডান বক্সের নিজস্ব হেডিং ছাড়া, সেটা section heading নয়)।
    final sharedHeading = await label('উচ্চ কর্তৃপক্ষে জমার হিসাব', fontSize: 13, bold: true);
    // No ৳ symbol here, matching the matrix table's own convention above —
    // package:pdf's native text also mis-renders that glyph, and the report
    // header/title already establishes these are all BDT amounts.
    final remittanceLabels = await Future.wait([
      label('১. থানাসহ সকল ওয়ার্ডের বাস্তব জমা'),
      label('২. থানার ব্যয়'),
      label('থানার নিসাব (১ - ২)', bold: true),
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

    // Second box (bottom-right): সকল খাতের হিসাব (ওয়ার্ড ও থানা মিলিয়ে) — ৪টা
    // special criteria collapsed into একটা "থানার নিসাব" row (= উচ্চ
    // কর্তৃপক্ষে জমার হিসাব বক্সের ফলাফল) + আলাদা "থানার ব্যয়" ও "ওয়ার্ডের
    // মোট ব্যয়" rows, তারপর সব normal খাত — combinedColTotals থেকে (ওয়ার্ড +
    // থানা row একসাথে), শুধু ওয়ার্ড-only colTotals নয়। এই বক্সের নিজস্ব total
    // সবসময় ম্যাট্রিক্স টেবিলের নতুন "থানাসহ সর্বমোট" ঘরের সমান — see
    // DatabaseHelper.getMatrixReport.
    final normalCriteria = data.criteriaList.where((c) => !c.isSpecial).toList();
    final totalBoxHeading = await label('সকল খাতের হিসাব (ওয়ার্ড ও থানা মিলিয়ে)', fontSize: 13, bold: true);
    final thanaNisabLabel = await label('থানার নিসাব');
    final wardExpenseLabel = await label('ওয়ার্ডের মোট ব্যয়');
    final protisthanExpenseLabel = await label('থানার ব্যয়');
    final normalCriteriaLabels = await Future.wait(normalCriteria.map((c) => label(c.name)));
    final totalBoxTotalLabel = await label('সর্বমোট', bold: true);

    final normalCriteriaTotal =
        normalCriteria.fold<double>(0, (sum, c) => sum + (data.combinedColTotals[c.id!] ?? 0));
    final totalBoxTotal =
        thanaNisab + wardExpenseTotal + protisthanExpenseAmount + normalCriteriaTotal;

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
            children: [headerRow, ...wardRows, grandRow, thanaRowWidget, combinedGrandRow],
          ),
          pw.SizedBox(height: 12),
          footerNote,
          pw.SizedBox(height: 24),
          sharedHeading,
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                    remittanceRow(remittanceLabels[0], actualDepositTotal),
                    remittanceRow(remittanceLabels[1], protisthanExpenseAmount),
                    pw.Divider(color: PdfColors.grey400, height: 12),
                    remittanceRow(remittanceLabels[2], thanaNisab, bold: true),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
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
                    totalBoxHeading,
                    pw.SizedBox(height: 8),
                    remittanceRow(thanaNisabLabel, thanaNisab),
                    remittanceRow(wardExpenseLabel, wardExpenseTotal),
                    remittanceRow(protisthanExpenseLabel, protisthanExpenseAmount),
                    for (var i = 0; i < normalCriteria.length; i++)
                      remittanceRow(normalCriteriaLabels[i], data.combinedColTotals[normalCriteria[i].id!] ?? 0),
                    pw.Divider(color: PdfColors.grey400, height: 12),
                    remittanceRow(totalBoxTotalLabel, totalBoxTotal, bold: true),
                  ],
                ),
              ),
            ],
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
    required double actualDepositTotal,
    required double wardExpenseTotal,
    required double protisthanExpenseAmount,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      actualDepositTotal: actualDepositTotal,
      wardExpenseTotal: wardExpenseTotal,
      protisthanExpenseAmount: protisthanExpenseAmount,
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
    double actualDepositTotal = 0,
    double wardExpenseTotal = 0,
    double protisthanExpenseAmount = 0,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      actualDepositTotal: actualDepositTotal,
      wardExpenseTotal: wardExpenseTotal,
      protisthanExpenseAmount: protisthanExpenseAmount,
    );
    await File(path).writeAsBytes(await doc.save());
  }

  /// Opens Android's native print/preview dialog for the report.
  static Future<void> previewAndPrint({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
    required double actualDepositTotal,
    required double wardExpenseTotal,
    required double protisthanExpenseAmount,
  }) async {
    final doc = await _buildDocument(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      actualDepositTotal: actualDepositTotal,
      wardExpenseTotal: wardExpenseTotal,
      protisthanExpenseAmount: protisthanExpenseAmount,
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }
}
