import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../utils/bangla_utils.dart';
import '../utils/currency_formatter.dart';

/// Generates the Ward × Criteria matrix report as an .xlsx file (FR-8.8)
/// and shares it via the Android share sheet (FR-8.9). Fully offline (FR-8.10).
class ExcelExportService {
  static Future<File> generate({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
    required double totalCollection,
    required double expenseAmount,
    required double actualDepositAmount,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Report';
    final sheet = excel[sheetName]; // auto-creates the "Report" sheet
    // Drop the library's auto-created "Sheet1" (and any other stray sheet)
    // so the exported file only contains our report.
    for (final existing in excel.tables.keys.toList()) {
      if (existing != sheetName) {
        excel.delete(existing);
      }
    }
    excel.setDefaultSheet(sheetName);

    sheet.appendRow([
      TextCellValue('$protisthanName — ${BanglaMonths.label(month, year)}'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('ওয়ার্ড'),
      ...data.criteriaList.map((c) => TextCellValue(c.name)),
      TextCellValue('মোট'),
    ]);

    for (final w in data.wards) {
      sheet.appendRow([
        TextCellValue(w.name),
        ...data.criteriaList.map((c) => DoubleCellValue(data.amountFor(w.id!, c.id!))),
        DoubleCellValue(data.rowTotals[w.id!] ?? 0),
      ]);
    }

    sheet.appendRow([
      TextCellValue('সর্বমোট'),
      ...data.criteriaList.map((c) => DoubleCellValue(data.colTotals[c.id!] ?? 0)),
      DoubleCellValue(data.grandTotal),
    ]);

    // Higher-management remittance summary (১ - ২ = ৩), matching the PDF
    // report's footer section.
    final expectedDeposit = totalCollection - expenseAmount;
    final difference = actualDepositAmount - expectedDeposit;
    final matched = difference.abs() < 0.005;

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('উচ্চ কর্তৃপক্ষে জমার হিসাব')]);
    sheet.appendRow([TextCellValue('১. মোট কালেকশন'), DoubleCellValue(totalCollection)]);
    sheet.appendRow([TextCellValue('২. মোট খরচ'), DoubleCellValue(expenseAmount)]);
    sheet.appendRow([TextCellValue('প্রত্যাশিত জমা (১ - ২)'), DoubleCellValue(expectedDeposit)]);
    sheet.appendRow([TextCellValue('৩. উচ্চ কর্তৃপক্ষে প্রকৃত জমা'), DoubleCellValue(actualDepositAmount)]);
    sheet.appendRow([
      TextCellValue(matched
          ? 'মিলেছে ✓'
          : 'অমিল — পার্থক্য ${CurrencyFormatter.format(difference.abs(), withSymbol: false)}'),
    ]);

    final bytes = excel.save();
    final dir = await getTemporaryDirectory();
    final fileName = ReportFileName.build(
      protisthanName: protisthanName,
      month: month,
      year: year,
      extension: 'xlsx',
    );
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes!, flush: true);
    return file;
  }

  static Future<void> generateAndShare({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
    required double totalCollection,
    required double expenseAmount,
    required double actualDepositAmount,
  }) async {
    final file = await generate(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      totalCollection: totalCollection,
      expenseAmount: expenseAmount,
      actualDepositAmount: actualDepositAmount,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '$protisthanName — ${BanglaMonths.label(month, year)} ম্যাট্রিক্স রিপোর্ট',
      ),
    );
  }
}
