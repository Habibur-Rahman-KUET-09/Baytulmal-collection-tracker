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
    const sheetName = 'রিপোর্ট';
    final sheet = excel[sheetName]; // auto-creates the "রিপোর্ট" sheet
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

    // থানার নিজস্ব normal-খাত কালেকশন (থানার আয়) + নিসাব(১)/আয়(২)/বাস্তব
    // জমা(৪) — শুধু ব্যয়(৩) খালি থাকে, যেহেতু থানার ব্যয় এখানে কখনো এন্ট্রি
    // হয় না।
    sheet.appendRow([
      TextCellValue('থানা'),
      ...data.criteriaList.map(
        (c) => data.thanaRow.containsKey(c.id!)
            ? DoubleCellValue(data.thanaAmountFor(c.id!))
            : TextCellValue(''),
      ),
      DoubleCellValue(data.thanaRowTotal),
    ]);

    sheet.appendRow([
      TextCellValue('থানাসহ সর্বমোট'),
      ...data.criteriaList.map((c) => DoubleCellValue(data.combinedColTotals[c.id!] ?? 0)),
      DoubleCellValue(data.combinedGrandTotal),
    ]);

    // উচ্চ কর্তৃপক্ষে জমার হিসাব (১ - ২ = "থানার নিসাব", always computed —
    // no separate manually-typed figure anymore), matching the PDF
    // report's box.
    final thanaNisab = actualDepositTotal - protisthanExpenseAmount;

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('উচ্চ কর্তৃপক্ষে জমার হিসাব')]);
    sheet.appendRow([TextCellValue('১. থানাসহ সকল ওয়ার্ডের বাস্তব জমা'), DoubleCellValue(actualDepositTotal)]);
    sheet.appendRow([TextCellValue('২. থানার ব্যয়'), DoubleCellValue(protisthanExpenseAmount)]);
    sheet.appendRow([
      TextCellValue('থানার নিসাব (১ - ২)'),
      DoubleCellValue(thanaNisab),
    ]);

    // Second box: সকল খাতের হিসাব (ওয়ার্ড ও থানা মিলিয়ে) — ৪টা special
    // criteria collapsed into একটা "থানার নিসাব" row (= উচ্চ কর্তৃপক্ষে
    // জমার হিসাব বক্সের ফলাফল) + আলাদা "থানার ব্যয়" ও "ওয়ার্ডের মোট ব্যয়"
    // রো, তারপর সব normal খাত — combinedColTotals থেকে (ওয়ার্ড + থানা row
    // একসাথে)। এই বক্সের নিজস্ব total সবসময় ম্যাট্রিক্স টেবিলের "থানাসহ
    // সর্বমোট" ঘরের সমান।
    final normalCriteria = data.criteriaList.where((c) => !c.isSpecial).toList();
    final normalCriteriaTotal =
        normalCriteria.fold<double>(0, (sum, c) => sum + (data.combinedColTotals[c.id!] ?? 0));
    final totalBoxTotal =
        thanaNisab + wardExpenseTotal + protisthanExpenseAmount + normalCriteriaTotal;

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('সকল খাতের হিসাব (ওয়ার্ড ও থানা মিলিয়ে)')]);
    sheet.appendRow([TextCellValue('থানার নিসাব'), DoubleCellValue(thanaNisab)]);
    sheet.appendRow([TextCellValue('ওয়ার্ডের মোট ব্যয়'), DoubleCellValue(wardExpenseTotal)]);
    sheet.appendRow([TextCellValue('থানার ব্যয়'), DoubleCellValue(protisthanExpenseAmount)]);
    for (final c in normalCriteria) {
      sheet.appendRow([TextCellValue(c.name), DoubleCellValue(data.combinedColTotals[c.id!] ?? 0)]);
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
