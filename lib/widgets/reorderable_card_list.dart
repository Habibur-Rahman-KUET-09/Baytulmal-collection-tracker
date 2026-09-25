import 'package:flutter/material.dart';

import 'drag_handle.dart';

/// A scrolling list whose [items] can be dragged into a new order by the
/// handle each row gets, after an optional [header] and [pinned] rows that
/// never move (e.g. the special criteria).
///
/// [itemBuilder] receives the row's drag handle, or null for pinned rows and
/// when [canReorder] is false, and places it (usually as a ListTile's
/// leading widget).
class ReorderableCardList<T> extends StatelessWidget {
  final List<T> items;
  final List<T> pinned;
  final Key Function(T item) keyOf;
  final Widget Function(BuildContext context, T item, Widget? dragHandle) itemBuilder;
  final bool canReorder;
  final String dragTooltip;
  final ValueChanged<List<T>> onReorder;
  final EdgeInsets padding;
  final Widget? header;

  const ReorderableCardList({
    super.key,
    required this.items,
    this.pinned = const [],
    required this.keyOf,
    required this.itemBuilder,
    required this.canReorder,
    required this.dragTooltip,
    required this.onReorder,
    required this.padding,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: 0),
          sliver: SliverList.list(
            children: [
              ?header,
              for (final item in pinned) KeyedSubtree(key: keyOf(item), child: itemBuilder(context, item, null)),
            ],
          ),
        ),
        SliverPadding(
          padding: padding.copyWith(top: 0),
          sliver: SliverReorderableList(
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) {
              final reordered = [...items];
              reordered.insert(newIndex, reordered.removeAt(oldIndex));
              onReorder(reordered);
            },
            itemBuilder: (context, index) {
              final item = items[index];
              return KeyedSubtree(
                key: keyOf(item),
                child: itemBuilder(
                  context,
                  item,
                  canReorder ? DragHandle(index: index, tooltip: dragTooltip) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
