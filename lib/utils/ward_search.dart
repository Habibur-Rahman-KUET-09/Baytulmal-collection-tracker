/// Finding wards quickly when a থানা has many of them: search by name or
/// number (Bangla or English digits), and the next ward still waiting for
/// this month's entry.
class WardSearch {
  static const _bnDigits = '০১২৩৪৫৬৭৮৯';

  /// Lower case, Western digits and single spaces, so "পশ্চিম ৪",
  /// "পশ্চিম 4" and "  পশ্চিম  4 " all compare equal.
  static String normalize(String text) {
    final buffer = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      final i = _bnDigits.indexOf(ch);
      buffer.write(i >= 0 ? '$i' : ch);
    }
    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Whether a ward named [name] matches what was typed. Every word typed
  /// must appear in the name, so "৪ পশ্চিম" finds "পশ্চিম ৪" too.
  static bool matches(String name, String query) {
    final q = normalize(query);
    if (q.isEmpty) return true;
    final n = normalize(name);
    return q.split(' ').every(n.contains);
  }

  /// Index in [wardIds] of the next ward after [current] without an entry
  /// ([entered] holds the ids that have one), going round to the start;
  /// null when every other ward already has one.
  static int? nextPending(List<int> wardIds, int current, Set<int> entered) {
    for (var step = 1; step < wardIds.length; step++) {
      final i = (current + step) % wardIds.length;
      if (!entered.contains(wardIds[i])) return i;
    }
    return null;
  }
}
