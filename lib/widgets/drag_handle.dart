import 'package:flutter/material.dart';

/// Grab point for dragging a row of a reorderable list to a new position.
class DragHandle extends StatelessWidget {
  final int index;
  final String tooltip;

  const DragHandle({super.key, required this.index, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Tooltip(
        message: tooltip,
        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator)),
      ),
    );
  }
}
