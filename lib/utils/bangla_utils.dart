/// Bangla month names and small date helpers shared across screens.
class BanglaMonths {
  static const List<String> names = [
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

  static const List<String> shortNames = [
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

  /// e.g. "সেপ্টেম্বর ২০২৬"
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

  static String toBanglaDigits(num value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (final ch in s.split('')) {
      buffer.write(_digitMap[ch] ?? ch);
    }
    return buffer.toString();
  }
}
