import 'number_input.dart';

/// Formats BDT amounts using Bangladeshi digit grouping (last 3 digits,
/// then groups of 2 — e.g. 142500 -> "1,42,500"), in the app language's
/// digits: "৳ ১,৪২,৫০০" with বাংলা selected, "৳ 1,42,500" in English.
class CurrencyFormatter {
  static String format(num amount, {bool withSymbol = true}) {
    final isNegative = amount < 0;
    final rounded = amount.abs();
    final hasFraction = rounded % 1 != 0;
    final wholePart = rounded.truncate().toString();
    final grouped = _groupBangladeshi(wholePart);
    final fraction = hasFraction
        ? '.${(rounded - rounded.truncate()).toStringAsFixed(2).split('.')[1]}'
        : '';
    final sign = isNegative ? '-' : '';
    final symbol = withSymbol ? '৳ ' : '';
    return NumberInput.localize('$sign$symbol$grouped$fraction');
  }

  static String _groupBangladeshi(String digits) {
    if (digits.length <= 3) return digits;
    final lastThree = digits.substring(digits.length - 3);
    var remaining = digits.substring(0, digits.length - 3);
    final buffer = StringBuffer();
    while (remaining.length > 2) {
      buffer.write(',${remaining.substring(remaining.length - 2)}');
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) buffer.write(',$remaining');
    final reversedGroups = buffer.toString().split(',').reversed.where((s) => s.isNotEmpty).join(',');
    return '$reversedGroups,$lastThree';
  }

  /// Empty-cell display for the matrix report (FR-8.6): "—" when amount is
  /// zero/unentered, otherwise the formatted amount without the symbol.
  static String cellDisplay(num amount) {
    if (amount == 0) return '—';
    return format(amount, withSymbol: false);
  }
}
