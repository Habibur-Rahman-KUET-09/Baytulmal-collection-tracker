import 'dart:io';

import 'package:cross_file/cross_file.dart';
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
      TextCellValue('Ward'),
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

    final bytes = excel.save();
    final dir = await getTemporaryDirectory();
    final safeName = protisthanName.replaceAll(RegExp(r'[^\wঀ-৿]+'), '_');
    final file = File('${dir.path}/matrix_report_${safeName}_${year}_$month.xlsx');
    await file.writeAsBytes(bytes!, flush: true);
    return file;
  }

  static Future<void> generateAndShare({
    required String protisthanName,
    required int month,
    required int year,
    required MatrixReportData data,
  }) async {
    final file = await generate(
      protisthanName: protisthanName,
      month: month,
      year: year,
      data: data,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '$protisthanName — ${BanglaMonths.label(month, year)} ম্যাট্রিক্স রিপোর্ট',
      ),
    );
  }
}
