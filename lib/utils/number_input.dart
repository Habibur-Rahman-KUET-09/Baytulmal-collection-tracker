import 'package:flutter/services.dart';

import 'bangla_utils.dart';

/// Numbers follow the app language: with বাংলা selected they are typed and
/// shown as ০-৯, with English as 0-9 (see [BanglaMonths.useBangla], kept in
/// sync by LocaleProvider). Stored values are plain doubles either way.
class NumberInput {
  static const _banglaDigits = '০১২৩৪৫৬৭৮৯';
  static const _westernDigits = '0123456789';

  /// Rewrites every digit in [text] into the current language's digits.
  static String localize(String text) {
    final bangla = BanglaMonths.useBangla;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final western = _westernDigits.indexOf(ch);
      final bn = _banglaDigits.indexOf(ch);
      if (bangla && western >= 0) {
        buffer.write(_banglaDigits[western]);
      } else if (!bangla && bn >= 0) {
        buffer.write(_westernDigits[bn]);
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// A stored amount as it should appear in an input field: no trailing
  /// ".0", in the current language's digits.
  static String editable(double value) {
    final plain = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
    return localize(plain);
  }

  /// Bangla digits to 0-9; drops thousands separators and spaces.
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.trim().runes) {
      final ch = String.fromCharCode(rune);
      final bn = _banglaDigits.indexOf(ch);
      if (bn >= 0) {
        buffer.write(bn);
      } else if (ch == '٫') {
        buffer.write('.');
      } else if (ch != ',' && ch != '٬' && ch.trim().isNotEmpty) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// The typed amount, or null when empty or not a number.
  static double? parse(String? text) {
    if (text == null) return null;
    final normalized = normalize(text);
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }

  /// For amount fields: digits are turned into the current language's as
  /// they are typed, a decimal point is kept, and anything else is dropped.
  static List<TextInputFormatter> get formatters => const [_LanguageDigitsFormatter()];
}

class _LanguageDigitsFormatter extends TextInputFormatter {
  const _LanguageDigitsFormatter();

  static final _allowed = RegExp(r'[0-9০-৯.٫]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cursor = newValue.selection.isValid ? newValue.selection.extentOffset : newValue.text.length;
    final buffer = StringBuffer();
    var newCursor = 0;
    for (var i = 0; i < newValue.text.length; i++) {
      final ch = newValue.text[i];
      if (_allowed.hasMatch(ch)) {
        buffer.write(ch == '٫' ? '.' : NumberInput.localize(ch));
        if (i < cursor) newCursor++;
      }
    }
    final text = buffer.toString();
    if (text == newValue.text) return newValue;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: newCursor));
  }
}
