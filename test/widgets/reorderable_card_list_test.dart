import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baytulmal_collection_tracker/widgets/reorderable_card_list.dart';

Future<List<String>> _pump(
  WidgetTester tester, {
  required List<String> items,
  List<String> pinned = const [],
  bool canReorder = true,
}) async {
  final result = <String>[];
  var current = items;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => ReorderableCardList<String>(
          items: current,
          pinned: pinned,
          keyOf: (item) => ValueKey(item),
          canReorder: canReorder,
          dragTooltip: 'Drag to reorder',
          padding: const EdgeInsets.all(12),
          header: const Text('header'),
          onReorder: (reordered) {
            setState(() => current = reordered);
            result
              ..clear()
              ..addAll(reordered);
          },
          itemBuilder: (context, item, handle) => Card(
            child: ListTile(leading: handle, title: Text(item)),
          ),
        ),
      ),
    ),
  ));
  return result;
}

Future<void> _dragBelow(WidgetTester tester, String item, String target) async {
  final handle = find.descendant(
    of: find.widgetWithText(ListTile, item),
    matching: find.byIcon(Icons.drag_indicator),
  );
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump();
  // Just past the target row's middle, in steps like a real finger.
  final distance = tester.getCenter(find.text(target)).dy - tester.getCenter(find.text(item)).dy + 8;
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(Offset(0, distance / 10));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dragging a row by its handle moves it', (tester) async {
    final result = await _pump(tester, items: ['A', 'B', 'C']);
    await _dragBelow(tester, 'A', 'B');
    expect(result, ['B', 'A', 'C']);
    await _dragBelow(tester, 'A', 'C');
    expect(result, ['B', 'C', 'A']);
    final order = ['A', 'B', 'C']..sort((x, y) => tester.getTopLeft(find.text(x)).dy.compareTo(tester.getTopLeft(find.text(y)).dy));
    expect(order, ['B', 'C', 'A']);
  });

  testWidgets('pinned rows have no handle and stay first', (tester) async {
    await _pump(tester, items: ['x', 'y'], pinned: ['special']);
    expect(find.descendant(of: find.widgetWithText(ListTile, 'special'), matching: find.byIcon(Icons.drag_indicator)),
        findsNothing);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    expect(tester.getTopLeft(find.text('special')).dy, lessThan(tester.getTopLeft(find.text('x')).dy));
    expect(find.text('header'), findsOneWidget);
  });

  testWidgets('no handles when reordering is not allowed', (tester) async {
    await _pump(tester, items: ['x', 'y'], canReorder: false);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
  });
}
