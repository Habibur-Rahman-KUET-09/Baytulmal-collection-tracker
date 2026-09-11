/// Formats BDT amounts using Bangladeshi digit grouping (last 3 digits,
/// then groups of 2 — e.g. 142500 -> "1,42,500") with Arabic numerals, as
/// recommended by the SRS (section 1.4) for reliable calculation display.
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
    return '$sign$symbol$grouped$fraction';
  }

  /// "১৮,০০০" style display is intentionally not used app-wide; SRS
  /// recommends Arabic numerals for reliable calculation display. This
  /// helper is kept for report headers that want the visual convention
  /// shown in the wireframes.
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
