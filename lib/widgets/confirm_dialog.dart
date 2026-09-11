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
