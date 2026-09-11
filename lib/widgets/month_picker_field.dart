import 'package:flutter/material.dart';

import '../utils/bangla_utils.dart';

/// Month/Year picker shown as a tappable field (matches the wireframe's
/// "সেপ্টেম্বর ২০২৬ ▾" control), used by the entry form and summary screens
/// (FR-4.6).
class MonthPickerField extends StatelessWidget {
  final int month;
  final int year;
  final ValueChanged<DateTime> onChanged;

  const MonthPickerField({
    super.key,
    required this.month,
    required this.year,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    int selectedMonth = month;
    int selectedYear = year;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setSheetState(() => selectedYear--),
                        ),
                        Text(
                          BanglaMonths.toBanglaDigits(selectedYear),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setSheetState(() => selectedYear++),
                        ),
                      ],
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final m = index + 1;
                        final selected = m == selectedMonth;
                        return Padding(
                          padding: const EdgeInsets.all(4),
                          child: ChoiceChip(
                            label: Text(BanglaMonths.names[index]),
                            selected: selected,
                            onSelected: (_) {
                              onChanged(DateTime(selectedYear, m));
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(BanglaMonths.label(month, year)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
