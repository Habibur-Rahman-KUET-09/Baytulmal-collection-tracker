import 'package:flutter_test/flutter_test.dart';

import 'package:baytulmal_collection_tracker/utils/bangla_utils.dart';
import 'package:baytulmal_collection_tracker/utils/currency_formatter.dart';

void main() {
  tearDown(() => BanglaMonths.useBangla = true);

  test('CurrencyFormatter groups amounts using Bangladeshi (lakh) style', () {
    BanglaMonths.useBangla = false;
    expect(CurrencyFormatter.format(142500), '৳ 1,42,500');
    expect(CurrencyFormatter.format(62500), '৳ 62,500');
    expect(CurrencyFormatter.format(500), '৳ 500');
    expect(CurrencyFormatter.format(-1250.5), '-৳ 1,250.50');
    expect(CurrencyFormatter.cellDisplay(0), '—');
  });

  test('CurrencyFormatter shows Bangla digits when বাংলা is selected', () {
    BanglaMonths.useBangla = true;
    expect(CurrencyFormatter.format(142500), '৳ ১,৪২,৫০০');
    expect(CurrencyFormatter.format(9000, withSymbol: false), '৯,০০০');
    expect(CurrencyFormatter.cellDisplay(1250.5), '১,২৫০.৫০');
  });
}
