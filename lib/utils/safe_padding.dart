import 'package:flutter/widgets.dart';

/// `EdgeInsets.all(amount)` plus the bottom system-gesture-nav inset.
///
/// Android's edge-to-edge display (enforced from Android 15 / targetSdk 35)
/// lets a Scaffold body's content draw underneath the bottom gesture bar.
/// The AppBar already clears the top inset, but a plain `ListView`/`Column`
/// body does not clear the bottom one on its own — the last item ends up
/// partially hidden behind the gesture bar. Use this instead of
/// `EdgeInsets.all(amount)` for any screen's outermost scrollable padding.
EdgeInsets safeBodyPadding(BuildContext context, {double amount = 16}) {
  return EdgeInsets.fromLTRB(
    amount,
    amount,
    amount,
    amount + MediaQuery.paddingOf(context).bottom,
  );
}
