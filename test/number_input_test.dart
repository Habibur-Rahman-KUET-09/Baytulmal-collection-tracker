import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baytulmal_collection_tracker/utils/bangla_utils.dart';
import 'package:baytulmal_collection_tracker/utils/number_input.dart';

String type(String text) {
  var value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  for (final f in NumberInput.formatters) {
    value = f.formatEditUpdate(TextEditingValue.empty, value);
  }
  return value.text;
}

void main() {
  tearDown(() => BanglaMonths.useBangla = true);

  test('বাংলা: every typed digit becomes Bangla, letters are dropped', () {
    BanglaMonths.useBangla = true;
    expect(type('9000'), '৯০০০');
    expect(type('৯০০০'), '৯০০০');
    expect(type('12.50'), '১২.৫০');
    expect(type('9000 টাকা'), '৯০০০');
    expect(NumberInput.editable(9000), '৯০০০');
    expect(NumberInput.editable(1250.5), '১২৫০.৫');
    expect(NumberInput.localize('5/100'), '৫/১০০');
  });

  test('English: every typed digit becomes English', () {
    BanglaMonths.useBangla = false;
    expect(type('৯০০০'), '9000');
    expect(type('9000'), '9000');
    expect(type('১২.৫০'), '12.50');
    expect(NumberInput.editable(9000), '9000');
    expect(NumberInput.localize('৫/১০০'), '5/100');
  });

  test('the cursor stays after the last kept character', () {
    BanglaMonths.useBangla = true;
    final value = NumberInput.formatters.first.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '9a0', selection: TextSelection.collapsed(offset: 3)),
    );
    expect(value.text, '৯০');
    expect(value.selection.extentOffset, 2);
  });

  test('parsing reads either digit set, so stored values never depend on the language', () {
    expect(NumberInput.parse('৯০০০'), 9000);
    expect(NumberInput.parse('9000'), 9000);
    expect(NumberInput.parse('১২৫০.৫০'), 1250.5);
    expect(NumberInput.parse('১,৪২,৫০০'), 142500);
    expect(NumberInput.parse(''), isNull);
    expect(NumberInput.parse(null), isNull);
    expect(NumberInput.parse('১.২.৩'), isNull);
  });
}
