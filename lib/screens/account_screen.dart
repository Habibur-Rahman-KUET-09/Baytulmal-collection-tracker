import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/locale_provider.dart';
import '../l10n/strings.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
import 'help_screen.dart';

/// আমার অ্যাকাউন্ট — প্রোফাইল তথ্য, ভাষা, পাসওয়ার্ড পরিবর্তন (শুধু ইমেইল/
/// পাসওয়ার্ড অ্যাকাউন্টের জন্য), অ্যাকাউন্ট মুছে ফেলা, ব্যবহার নির্দেশনা ও লগআউট।
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  String _friendlyError(Strings s, Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return s.loginErrorWrongPassword;
        case 'weak-password':
          return s.accountErrorWeakNewPassword;
        case 'requires-recent-login':
          return s.accountErrorRequiresRecentLogin;
        case 'network-request-failed':
          return s.loginErrorNetwork;
        case 'missing-google-id-token':
          return s.loginErrorMissingGoogleToken;
        case 'no-current-user':
          return s.loginErrorNoCurrentUser;
        case 'missing-password':
          return s.loginErrorMissingPassword;
        default:
          return e.message ?? s.accountErrorGeneric;
      }
    }
    return e.toString();
  }

  Future<void> _changePassword(Strings s) async {
    final result = await _showChangePasswordDialog(s);
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.changePassword(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.accountPasswordChanged)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(s, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ChangePasswordResult?> _showChangePasswordDialog(Strings s) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<_ChangePasswordResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.accountChangePasswordDialogTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: s.accountCurrentPassword),
                validator: (v) => (v == null || v.isEmpty) ? s.required : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: s.accountNewPassword),
                validator: (v) {
                  if (v == null || v.isEmpty) return s.required;
                  if (v.length < 8) return s.loginPasswordTooShort;
                  if (!RegExp(r'[0-9]').hasMatch(v)) return s.loginPasswordNeedsDigit;
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: s.accountConfirmNewPassword),
                validator: (v) => v != newCtrl.text ? s.loginPasswordMismatch : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(
                _ChangePasswordResult(currentCtrl.text, newCtrl.text),
              );
            },
            child: Text(s.accountChangeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(Strings s) async {
    setState(() => _busy = true);
    List<String> creatorOf;
    try {
      creatorOf = await CloudSyncService.instance.myCreatorProtisthanNames();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(s, e))));
      }
      setState(() => _busy = false);
      return;
    }
    setState(() => _busy = false);
    if (!mounted) return;

    if (creatorOf.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.accountCannotDeleteTitle),
          content: Text(s.accountCannotDeleteMessage(creatorOf.map((n) => '• $n').join('\n'))),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(s.ok)),
          ],
        ),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: s.accountDeleteConfirmTitle,
      message: s.accountDeleteConfirmMessage,
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
    );
    if (!confirmed || !mounted) return;

    String? currentPassword;
    if (AuthService.instance.isPasswordUser) {
      currentPassword = await _showPasswordPromptDialog(s);
      if (currentPassword == null || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      await CloudSyncService.instance.deleteOwnAccountData();
      await AuthService.instance.deleteAccount(currentPassword: currentPassword);
      // On success, AuthGate's authStateChanges listener takes the user
      // back to LoginScreen automatically — no manual navigation needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(s, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showPasswordPromptDialog(Strings s) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.accountConfirmPasswordTitle),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(labelText: s.accountCurrentPassword),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: Text(s.accountConfirmButton),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(Strings s) async {
    final confirmed = await showConfirmDialog(
      context,
      title: s.accountLogoutTitle,
      message: s.accountLogoutMessage,
      confirmLabel: s.accountLogout,
      cancelLabel: s.cancel,
      isDestructive: false,
    );
    if (confirmed && mounted) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final user = AuthService.instance.currentUser;
    final isPasswordUser = AuthService.instance.isPasswordUser;

    return Scaffold(
      appBar: AppBar(title: Text(s.accountTitle)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: safeBodyPadding(context),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  user?.displayName?.isNotEmpty == true ? user!.displayName! : (user?.email ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(user?.email ?? ''),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(s.accountLanguage),
                trailing: SegmentedButton<AppLanguage>(
                  segments: [
                    ButtonSegment(value: AppLanguage.bn, label: Text(s.accountLanguageBangla)),
                    ButtonSegment(value: AppLanguage.en, label: Text(s.accountLanguageEnglish)),
                  ],
                  selected: {localeProvider.language},
                  onSelectionChanged: (selected) => localeProvider.setLanguage(selected.first),
                ),
              ),
            ),
            if (isPasswordUser)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(s.accountChangePassword),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _changePassword(s),
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(s.accountHowItWorks),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(s.accountSop),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SopScreen()),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
                title: Text(s.accountDeleteAccount, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: Text(s.accountDeleteSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _deleteAccount(s),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: _busy ? null : () => _signOut(s),
              icon: const Icon(Icons.logout),
              label: Text(s.accountLogout),
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordResult {
  final String currentPassword;
  final String newPassword;
  const _ChangePasswordResult(this.currentPassword, this.newPassword);
}
