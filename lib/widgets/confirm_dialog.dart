import 'package:flutter/material.dart';

/// Bangla confirmation dialog required before any destructive action
/// (FR-1.4, FR-2.4, FR-3.4, FR-7.2).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'মুছে ফেলুন',
  String cancelLabel = 'বাতিল',
  bool isDestructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Simple text-input dialog used for add/rename flows (Protisthan, Ward,
/// Criteria).
Future<String?> showNameInputDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String hintText = '',
  String label = 'নাম',
}) async {
  final controller = TextEditingController(text: initialValue ?? '');
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: label, hintText: hintText),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'নাম আবশ্যক' : null,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('বাতিল'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
          child: const Text('সংরক্ষণ করুন'),
        ),
      ],
    ),
  );
  return result;
}

class ProtisthanInputResult {
  final String name;
  final double nisab;
  const ProtisthanInputResult({required this.name, required this.nisab});
}

/// Add/rename dialog for a থানা — also collects/edits its hidden থানা
/// ward's fixed ধার্যকৃত নিসাব (special criteria ১), same pattern as
/// [showWardInputDialog].
Future<ProtisthanInputResult?> showProtisthanInputDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  double initialNisab = 0,
}) async {
  final nameCtrl = TextEditingController(text: initialName ?? '');
  final nisabCtrl = TextEditingController(
    text: initialNisab == 0 ? '' : _trimZero(initialNisab),
  );
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<ProtisthanInputResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'থানার নাম'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'নাম আবশ্যক' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nisabCtrl,
              decoration: const InputDecoration(
                labelText: 'ধার্যকৃত নিসাব (৳)',
                helperText: 'ঐচ্ছিক — খালি রাখলে ০ ধরা হবে।',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'সঠিক সংখ্যা দিন';
                if (parsed < 0) return 'ঋণাত্মক মান গ্রহণযোগ্য নয়';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('বাতিল'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(ProtisthanInputResult(
                name: nameCtrl.text.trim(),
                nisab: double.tryParse(nisabCtrl.text.trim()) ?? 0,
              ));
            }
          },
          child: const Text('সংরক্ষণ করুন'),
        ),
      ],
    ),
  );
  return result;
}

class WardInputResult {
  final String name;
  final double targetAmount;
  const WardInputResult({required this.name, required this.targetAmount});
}

/// Add/rename dialog for a Ward — also collects/edits its fixed
/// ধার্যকৃত নিসাব (special criteria ১, set once and not part of any
/// per-month Entry).
Future<WardInputResult?> showWardInputDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  double initialTargetAmount = 0,
}) async {
  final nameCtrl = TextEditingController(text: initialName ?? '');
  final targetCtrl = TextEditingController(
    text: initialTargetAmount == 0 ? '' : _trimZero(initialTargetAmount),
  );
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<WardInputResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'ওয়ার্ডের নাম'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'নাম আবশ্যক' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: targetCtrl,
              decoration: const InputDecoration(
                labelText: 'ধার্যকৃত নিসাব (৳)',
                helperText: 'ঐচ্ছিক — খালি রাখলে ০ ধরা হবে। প্রতি মাসের আয় ও ব্যয়ের '
                    'সাথে মিলিয়ে দেখা হবে (আয় − ব্যয় = বাস্তব জমা)।',
                helperMaxLines: 2,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'সঠিক সংখ্যা দিন';
                if (parsed < 0) return 'ঋণাত্মক মান গ্রহণযোগ্য নয়';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('বাতিল'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(WardInputResult(
                name: nameCtrl.text.trim(),
                targetAmount: double.tryParse(targetCtrl.text.trim()) ?? 0,
              ));
            }
          },
          child: const Text('সংরক্ষণ করুন'),
        ),
      ],
    ),
  );
  return result;
}

String _trimZero(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}
