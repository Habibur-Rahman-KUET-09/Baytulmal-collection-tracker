import 'package:flutter/widgets.dart';

/// A FloatingActionButton is ~56dp tall, sits 16dp off the Scaffold edge,
/// and a scrolled-up list's last item should still clear it with some
/// breathing room — this is that total extra bottom space.
const double kFabClearance = 88;

/// `EdgeInsets.all(amount)` plus the bottom system-gesture-nav inset, and
/// optionally extra room so a `floatingActionButton` never overlaps the
/// last item of a scrollable body.
///
/// Android's edge-to-edge display (enforced from Android 15 / targetSdk 35)
/// lets a Scaffold body's content draw underneath the bottom gesture bar.
/// The AppBar already clears the top inset, but a plain `ListView`/`Column`
/// body does not clear the bottom one on its own — the last item ends up
/// partially hidden behind the gesture bar (and, separately, behind a FAB
/// docked over the content). Use this instead of `EdgeInsets.all(amount)`
/// for any screen's outermost scrollable padding, passing `fab: true` when
/// the Scaffold has a `floatingActionButton`.
EdgeInsets safeBodyPadding(BuildContext context, {double amount = 16, bool fab = false}) {
  return EdgeInsets.fromLTRB(
    amount,
    amount,
    amount,
    amount + MediaQuery.paddingOf(context).bottom + (fab ? kFabClearance : 0),
  );
}
