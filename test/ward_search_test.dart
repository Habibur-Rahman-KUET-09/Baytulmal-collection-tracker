import 'package:flutter_test/flutter_test.dart';

import 'package:baytulmal_collection_tracker/utils/ward_search.dart';

void main() {
  group('WardSearch.matches', () {
    test('finds a ward by its number in Bangla or English digits', () {
      expect(WardSearch.matches('পশ্চিম ৪', '৪'), isTrue);
      expect(WardSearch.matches('পশ্চিম ৪', '4'), isTrue);
      expect(WardSearch.matches('Ward 12', '১২'), isTrue);
      expect(WardSearch.matches('পশ্চিম ৪', '৫'), isFalse);
    });

    test('ignores case, extra spaces and word order', () {
      expect(WardSearch.matches('Paschim 3', '  paschim   3 '), isTrue);
      expect(WardSearch.matches('পশ্চিম ৪', '৪ পশ্চিম'), isTrue);
      expect(WardSearch.matches('পশ্চিম ৪', 'পূর্ব'), isFalse);
    });

    test('an empty search matches everything', () {
      expect(WardSearch.matches('পশ্চিম ১', ''), isTrue);
      expect(WardSearch.matches('পশ্চিম ১', '   '), isTrue);
    });
  });

  group('WardSearch.nextPending', () {
    const ids = [10, 20, 30, 40, 50];

    test('goes to the next ward without an entry', () {
      expect(WardSearch.nextPending(ids, 0, {}), 1);
      expect(WardSearch.nextPending(ids, 0, {20, 30}), 3);
    });

    test('goes round to the start after the last ward', () {
      expect(WardSearch.nextPending(ids, 4, {10}), 1);
    });

    test('never picks the ward being entered, and is null when all are done', () {
      expect(WardSearch.nextPending(ids, 2, {10, 20, 40, 50}), isNull);
      expect(WardSearch.nextPending(ids, 2, {10, 20, 30, 40, 50}), isNull);
      expect(WardSearch.nextPending(const [10], 0, {}), isNull);
    });
  });
}
