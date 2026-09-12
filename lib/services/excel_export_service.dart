import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../utils/bangla_utils.dart';

/// Generates the Ward × Criteria matrix report as an .xlsx file (FR-8.8)
/// and shares it via the Android share sheet (FR-8.9). Fully offline (FR-8.10).
class ExcelExportService {
  static Future<File> generate({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
    required double actualDepositTotal,
    required double wardExpenseTotal,
    required double protisthanExpenseAmount,
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

    // উচ্চ কর্তৃপক্ষে জমার হিসাব (১ - ২ = "প্রতিষ্ঠানের বাস্তব জমা", always
    // computed — no separate manually-typed figure anymore), matching the
    // PDF report's box.
    final protisthanActualDeposit = actualDepositTotal - protisthanExpenseAmount;

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('উচ্চ কর্তৃপক্ষে জমার হিসাব')]);
    sheet.appendRow([TextCellValue('১. বাস্তব জমা'), DoubleCellValue(actualDepositTotal)]);
    sheet.appendRow([TextCellValue('২. $protisthanName ব্যয়'), DoubleCellValue(protisthanExpenseAmount)]);
    sheet.appendRow([
      TextCellValue('প্রতিষ্ঠানের বাস্তব জমা (১ - ২)'),
      DoubleCellValue(protisthanActualDeposit),
    ]);

    // Second box: per-criteria totals for the Protisthan, but with the
    // ৪টা special criteria collapsed into একটা "প্রতিষ্ঠানের বাস্তব জমা"
    // row (= উচ্চ কর্তৃপক্ষে জমার হিসাব বক্সের ফলাফল) + separate ওয়ার্ডের
    // ব্যয়ের যোগফল and {protisthanName} ব্যয় rows. This section's own
    // total always equals the matrix table's grand total (সর্বমোট) above.
    final normalCriteria = data.criteriaList.where((c) => !c.isSpecial).toList();
    final normalCriteriaTotal =
        normalCriteria.fold<double>(0, (sum, c) => sum + (data.colTotals[c.id!] ?? 0));
    final totalBoxTotal =
        protisthanActualDeposit + wardExpenseTotal + protisthanExpenseAmount + normalCriteriaTotal;

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('প্রতিষ্ঠান টোটাল হিসাব')]);
    sheet.appendRow([TextCellValue('প্রতিষ্ঠানের বাস্তব জমা'), DoubleCellValue(protisthanActualDeposit)]);
    sheet.appendRow([TextCellValue('ওয়ার্ডের ব্যয়ের যোগফল'), DoubleCellValue(wardExpenseTotal)]);
    sheet.appendRow([TextCellValue('$protisthanName ব্যয়'), DoubleCellValue(protisthanExpenseAmount)]);
    for (final c in normalCriteria) {
      sheet.appendRow([TextCellValue(c.name), DoubleCellValue(data.colTotals[c.id!] ?? 0)]);
    }
    sheet.appendRow([TextCellValue('সর্বমোট'), DoubleCellValue(totalBoxTotal)]);

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
    required double actualDepositTotal,
    required double wardExpenseTotal,
    required double protisthanExpenseAmount,
  }) async {
    final file = await generate(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
      actualDepositTotal: actualDepositTotal,
      wardExpenseTotal: wardExpenseTotal,
      protisthanExpenseAmount: protisthanExpenseAmount,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '$protisthanName — ${BanglaMonths.label(month, year)} ম্যাট্রিক্স রিপোর্ট',
      ),
    );
  }
}
