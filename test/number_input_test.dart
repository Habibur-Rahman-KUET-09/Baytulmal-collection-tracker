import 'package:flutter_test/flutter_test.dart';

import 'package:baytulmal_collection_tracker/utils/number_input.dart';

void main() {
  test('reads amounts typed with Bangla digits', () {
    expect(NumberInput.parse('৯০০০'), 9000);
    expect(NumberInput.parse('১২৫০.৫০'), 1250.5);
    expect(NumberInput.parse('১,৪২,৫০০'), 142500);
    expect(NumberInput.parse(' 9000 '), 9000);
    expect(NumberInput.parse('৯০0০'), 9000); // mixed keyboards
    expect(NumberInput.parse('২٫৫'), 2.5);
  });

  test('empty or invalid input is null', () {
    expect(NumberInput.parse(''), isNull);
    expect(NumberInput.parse('   '), isNull);
    expect(NumberInput.parse(null), isNull);
    expect(NumberInput.parse('abc'), isNull);
    expect(NumberInput.parse('১.২.৩'), isNull);
  });

  test('amount fields let Bangla digits through and drop letters', () {
    var value = const TextEditingValue(text: '৯০০০ টাকা.৫');
    for (final f in NumberInput.formatters) {
      value = f.formatEditUpdate(const TextEditingValue(), value);
    }
    expect(value.text, '৯০০০.৫');
  });
}
