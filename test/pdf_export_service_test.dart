// Regression test for the matrix report PDF, including the fix for
// package:pdf's broken Bengali pre-base vowel shaping (see
// lib/utils/bangla_pdf_text.dart) and the higher-management remittance
// section. This can't assert pixel-correctness of the shaped text, but it
// does verify the whole pipeline (font loading, dart:ui rasterization,
// pw.Document assembly) runs end-to-end without throwing and produces a
// non-trivial PDF. Rendering was manually verified via `pdftoppm` during
// development — see the commit that introduced this file.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baytulmal_collection_tracker/db/database_helper.dart';
import 'package:baytulmal_collection_tracker/models/criteria.dart';
import 'package:baytulmal_collection_tracker/models/ward.dart';
import 'package:baytulmal_collection_tracker/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('matrix report PDF (with remittance section) generates successfully', () async {
    final regular = await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf');
    final loader = FontLoader('NotoSansBengali')
      ..addFont(Future.value(regular))
      ..addFont(Future.value(bold));
    await loader.load();

    final w1 = Ward(id: 1, uuid: 'w1', protisthanId: 1, name: 'ওয়ার্ড ১', createdAt: '', targetAmount: 20000);
    final w2 = Ward(id: 2, uuid: 'w2', protisthanId: 1, name: 'ওয়ার্ড ২', createdAt: '', targetAmount: 15000);
    final cNisab = Criteria(id: 1, uuid: 'c1', protisthanId: 1, name: 'ধার্যকৃত নিসাব', createdAt: '', specialOrder: 1);
    final cIncome = Criteria(id: 2, uuid: 'c2', protisthanId: 1, name: 'আয়', createdAt: '', specialOrder: 2);
    final cExpense = Criteria(id: 3, uuid: 'c3', protisthanId: 1, name: 'ব্যয়', createdAt: '', specialOrder: 3);
    final cDeposit = Criteria(id: 4, uuid: 'c4', protisthanId: 1, name: 'বাস্তব জমা', createdAt: '', specialOrder: 4);
    final cRent = Criteria(id: 5, uuid: 'c5', protisthanId: 1, name: 'দোকান ভাড়া', createdAt: '');

    final data = MatrixReportData(
      wards: [w1, w2],
      criteriaList: [cNisab, cIncome, cExpense, cDeposit, cRent],
      cells: {
        1: {1: 20000, 2: 8000, 3: 2000, 4: 6000, 5: 5500},
        2: {1: 15000, 2: 4000, 3: 1000, 4: 3000, 5: 3000},
      },
      // ওয়ার্ড টোটাল = ব্যয়(৩) + বাস্তব জমা(৪) + normal, ধার্যকৃত নিসাব(১) ও
      // আয়(২) বাদে।
      rowTotals: {1: 13500, 2: 7000},
      colTotals: {1: 35000, 2: 12000, 3: 3000, 4: 9000, 5: 8500},
      grandTotal: 20500,
      // থানার নিজস্ব normal-খাত কালেকশন (থানার আয়) — special columns বাদে।
      thanaRow: {5: 1200},
      thanaRowTotal: 1200,
      combinedColTotals: {1: 35000, 2: 12000, 3: 3000, 4: 9000, 5: 9700},
      combinedGrandTotal: 21700,
    );

    final path = '${Directory.systemTemp.path}/pdf_export_service_test.pdf';
    await PdfExportService.dumpForTest(
      path: path,
      protisthanName: 'কারওয়ান বাজার',
      month: 9,
      year: 2026,
      data: data,
      actualDepositTotal: 9000,
      wardExpenseTotal: 3000,
      protisthanExpenseAmount: 2000,
    );

    final file = File(path);
    expect(file.existsSync(), isTrue);
    // A real multi-row table plus several rasterized Bangla-text images is
    // always well above a trivial byte count; a near-empty file would mean
    // something in the pipeline silently failed.
    expect(file.lengthSync(), greaterThan(10000));
    file.deleteSync();
  });
}
