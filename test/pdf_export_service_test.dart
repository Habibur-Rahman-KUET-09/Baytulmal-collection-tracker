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

    final w1 = Ward(id: 1, uuid: 'w1', protisthanId: 1, name: 'ওয়ার্ড ১', createdAt: '');
    final w2 = Ward(id: 2, uuid: 'w2', protisthanId: 1, name: 'ওয়ার্ড ২', createdAt: '');
    final c1 = Criteria(id: 1, uuid: 'c1', protisthanId: 1, name: 'দোকান ভাড়া', createdAt: '');
    final c2 = Criteria(id: 2, uuid: 'c2', protisthanId: 1, name: 'আদায়', createdAt: '', specialOrder: 2);
    final c3 = Criteria(id: 3, uuid: 'c3', protisthanId: 1, name: 'বকেয়া', createdAt: '', specialOrder: 3);

    final data = MatrixReportData(
      wards: [w1, w2],
      criteriaList: [c1, c2, c3],
      cells: {
        1: {1: 18000, 2: 5500},
        2: {1: 15000, 2: 4000, 3: 3000},
      },
      rowTotals: {1: 23500, 2: 22000},
      colTotals: {1: 33000, 2: 9500, 3: 3000},
      grandTotal: 45500,
    );

    final path = '${Directory.systemTemp.path}/pdf_export_service_test.pdf';
    await PdfExportService.dumpForTest(
      path: path,
      protisthanName: 'কারওয়ান বাজার',
      month: 9,
      year: 2026,
      data: data,
      totalCollection: 45500,
      expenseAmount: 8000,
      actualDepositAmount: 37000,
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
