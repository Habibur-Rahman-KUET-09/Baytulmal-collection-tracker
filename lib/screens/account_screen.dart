import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../utils/safe_padding.dart';
import '../widgets/confirm_dialog.dart';
import 'help_screen.dart';

/// আমার অ্যাকাউন্ট — প্রোফাইল তথ্য, পাসওয়ার্ড পরিবর্তন (শুধু ইমেইল/পাসওয়ার্ড
/// অ্যাকাউন্টের জন্য), অ্যাকাউন্ট মুছে ফেলা, ব্যবহার নির্দেশনা ও লগআউট।
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'পাসওয়ার্ড সঠিক নয়।';
        case 'weak-password':
          return 'নতুন পাসওয়ার্ড খুবই দুর্বল — কমপক্ষে ৮ অক্ষর, একটি সংখ্যা সহ দিন।';
        case 'requires-recent-login':
          return 'নিরাপত্তার জন্য আবার সাইন-ইন করে চেষ্টা করুন।';
        case 'network-request-failed':
          return 'ইন্টারনেট সংযোগ পরীক্ষা করুন।';
        default:
          return e.message ?? 'একটি সমস্যা হয়েছে।';
      }
    }
    return e.toString();
  }

  Future<void> _changePassword() async {
    final result = await _showChangePasswordDialog();
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.changePassword(
        currentPassword: result.currentPassword,
        newPassword: result.newPassword,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('পাসওয়ার্ড পরিবর্তন করা হয়েছে')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ChangePasswordResult?> _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<_ChangePasswordResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('পাসওয়ার্ড পরিবর্তন'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'বর্তমান পাসওয়ার্ড'),
                validator: (v) => (v == null || v.isEmpty) ? 'আবশ্যক' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'আবশ্যক';
                  if (v.length < 8) return 'কমপক্ষে ৮ অক্ষর দিন';
                  if (!RegExp(r'[0-9]').hasMatch(v)) return 'অন্তত একটি সংখ্যা দিন';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড নিশ্চিত করুন'),
                validator: (v) => v != newCtrl.text ? 'পাসওয়ার্ড মিলছে না' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('বাতিল')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(
                _ChangePasswordResult(currentCtrl.text, newCtrl.text),
              );
            },
            child: const Text('পরিবর্তন করুন'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _busy = true);
    List<String> creatorOf;
    try {
      creatorOf = await CloudSyncService.instance.myCreatorProtisthanNames();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
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
          title: const Text('অ্যাকাউন্ট মুছে ফেলা যাবে না'),
          content: Text(
            'আপনি নিচের থানাগুলোর নির্মাতা — এগুলো আগে মুছে ফেলুন বা অন্য থানায় '
            'সরিয়ে নিন, তারপর অ্যাকাউন্ট মুছুন:\n\n${creatorOf.map((n) => '• $n').join('\n')}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('ঠিক আছে')),
          ],
        ),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'অ্যাকাউন্ট মুছে ফেলবেন?',
      message: 'আপনার প্রোফাইল, লগইন এবং সকল থানার সদস্যপদ স্থায়ীভাবে মুছে যাবে। '
          'এই কাজটি ফিরিয়ে নেওয়া যাবে না।',
      confirmLabel: 'মুছে ফেলুন',
    );
    if (!confirmed || !mounted) return;

    String? currentPassword;
    if (AuthService.instance.isPasswordUser) {
      currentPassword = await _showPasswordPromptDialog();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showPasswordPromptDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('পাসওয়ার্ড নিশ্চিত করুন'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'বর্তমান পাসওয়ার্ড'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('বাতিল')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: const Text('নিশ্চিত করুন'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'লগআউট করবেন?',
      message: 'আপনাকে আবার লগইন করতে হবে।',
      confirmLabel: 'লগআউট',
      isDestructive: false,
    );
    if (confirmed) {
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isPasswordUser = AuthService.instance.isPasswordUser;

    return Scaffold(
      appBar: AppBar(title: const Text('আমার অ্যাকাউন্ট')),
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
            if (isPasswordUser)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('পাসওয়ার্ড পরিবর্তন'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _changePassword,
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('কীভাবে কাজ করে'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('বিস্তারিত নিয়মকানুন (SOP)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SopScreen()),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
                title: Text('অ্যাকাউন্ট মুছে ফেলুন', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: const Text('আপনার প্রোফাইল ও লগইন স্থায়ীভাবে মুছে যাবে'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : _deleteAccount,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('লগআউট'),
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
