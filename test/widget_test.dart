import 'package:flutter_test/flutter_test.dart';

import 'package:baytulmal_collection_tracker/utils/currency_formatter.dart';

void main() {
  test('CurrencyFormatter groups amounts using Bangladeshi (lakh) style', () {
    expect(CurrencyFormatter.format(142500), '৳ 1,42,500');
    expect(CurrencyFormatter.format(62500), '৳ 62,500');
    expect(CurrencyFormatter.format(500), '৳ 500');
    expect(CurrencyFormatter.cellDisplay(0), '—');
  });
}
