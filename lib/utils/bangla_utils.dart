/// Month names and digit formatting shared across screens — locale-aware
/// via [BanglaMonths.useBangla], which [LocaleProvider] keeps in sync with
/// the device's bn/en language choice. Kept as a plain static flag (not a
/// ChangeNotifier) so the dozens of existing call sites across the app
/// don't each need a BuildContext/language parameter threaded through;
/// every screen already rebuilds on language change via
/// `Strings.of(context)`/`context.watch<LocaleProvider>()`, and by the
/// time that rebuild runs this flag has already been updated.
class BanglaMonths {
  /// True (the default) reads/writes Bangla month names + Bangla digits;
  /// false switches both to English/Western. Set by LocaleProvider.
  static bool useBangla = true;

  static const List<String> _bnNames = [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];

  static const List<String> _bnShortNames = [
    'জান',
    'ফেব্র',
    'মার্চ',
    'এপ্র',
    'মে',
    'জুন',
    'জুল',
    'আগ',
    'সেপ্ট',
    'অক্ট',
    'নভ',
    'ডিস',
  ];

  static const List<String> _enNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _enShortNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static List<String> get names => useBangla ? _bnNames : _enNames;
  static List<String> get shortNames => useBangla ? _bnShortNames : _enShortNames;

  /// e.g. "সেপ্টেম্বর ২০২৬" (bn) or "September 2026" (en)
  static String label(int month, int year) => '${names[month - 1]} ${toBanglaDigits(year)}';

  static String shortLabel(int month, int year) => shortNames[month - 1];

  static const Map<String, String> _digitMap = {
    '0': '০',
    '1': '১',
    '2': '২',
    '3': '৩',
    '4': '৪',
    '5': '৫',
    '6': '৬',
    '7': '৭',
    '8': '৮',
    '9': '৯',
  };

  /// Despite the name (kept for the many existing call sites), this
  /// renders Western digits when [useBangla] is false.
  static String toBanglaDigits(num value) {
    final s = value.toString();
    if (!useBangla) return s;
    final buffer = StringBuffer();
    for (final ch in s.split('')) {
      buffer.write(_digitMap[ch] ?? ch);
    }
    return buffer.toString();
  }
}

/// Shared filename for both the PDF and Excel matrix-report downloads:
/// "বাইতুলমাল রিপোর্ট - {প্রতিষ্ঠান} - {মাস} - {ডাউনলোড সময়}.{ext}" (bn) or
/// "Baytulmal Report - {name} - {month} - {timestamp}.{ext}" (en).
class ReportFileName {
  static String build({
    required String protisthanName,
    required int month,
    required int year,
    required String extension,
  }) {
    final now = DateTime.now();
    final stamp = '${_two(now.day)}-${_two(now.month)}-${now.year} '
        '${_two(now.hour)}-${_two(now.minute)}';
    final prefix = BanglaMonths.useBangla ? 'বাইতুলমাল রিপোর্ট' : 'Baytulmal Report';
    final raw = '$prefix - $protisthanName - '
        '${BanglaMonths.label(month, year)} - $stamp';
    // Strip characters that are invalid in filenames on Android/exFAT;
    // spaces, dashes and Bangla text are all safe and kept as typed.
    final safe = raw.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
    return '$safe.$extension';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
