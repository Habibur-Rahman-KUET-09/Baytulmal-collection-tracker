import 'package:flutter/services.dart';

/// Amounts typed on a Bangla keyboard use ০-৯ (and sometimes the Arabic
/// decimal mark or thousands commas); these helpers accept them alongside
/// 0-9 everywhere the app reads a typed number.
class NumberInput {
  static const _banglaDigits = '০১২৩৪৫৬৭৮৯';

  /// Bangla digits to 0-9; drops thousands separators and spaces.
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.trim().runes) {
      final ch = String.fromCharCode(rune);
      final bangla = _banglaDigits.indexOf(ch);
      if (bangla >= 0) {
        buffer.write(bangla);
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

  /// Lets amount fields accept Bangla and Western digits and a decimal point.
  static final formatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.٫,]')),
  ];
}
