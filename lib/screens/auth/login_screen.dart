import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/safe_padding.dart';

/// লগইন/নিবন্ধন — ইমেইল/পাসওয়ার্ড ও Google দুই পদ্ধতিতেই সাইন-ইন করা যায়।
/// [AuthGate] সরাসরি এই স্ক্রিন দেখায় যখন কেউ সাইন-ইন করা নেই।
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'ইমেইল ঠিকানাটি সঠিক নয়।';
      case 'user-disabled':
        return 'এই অ্যাকাউন্টটি নিষ্ক্রিয় করা হয়েছে।';
      case 'user-not-found':
      case 'invalid-credential':
        return 'এই ইমেইল/পাসওয়ার্ডে কোনো অ্যাকাউন্ট পাওয়া যায়নি।';
      case 'wrong-password':
        return 'পাসওয়ার্ড সঠিক নয়।';
      case 'email-already-in-use':
        return 'এই ইমেইল দিয়ে আগে থেকেই একটি অ্যাকাউন্ট আছে।';
      case 'weak-password':
        return 'পাসওয়ার্ড খুবই দুর্বল — কমপক্ষে ৬ অক্ষর দিন।';
      case 'network-request-failed':
        return 'ইন্টারনেট সংযোগ পরীক্ষা করুন।';
      case 'too-many-requests':
        return 'অনেকবার চেষ্টা করা হয়েছে — একটু পর আবার চেষ্টা করুন।';
      default:
        return e.message ?? 'একটি সমস্যা হয়েছে, আবার চেষ্টা করুন।';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    try {
      if (_isSignUp) {
        await AuthService.instance.signUpWithEmail(email: email, password: password);
      } else {
        await AuthService.instance.signInWithEmail(email: email, password: password);
      }
      // On success, AuthGate's authStateChanges listener takes over — no
      // manual navigation needed here.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _submitting = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google সাইন-ইন ব্যর্থ হয়েছে: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('আগে ইমেইল ঠিকানা লিখুন')));
      return;
    }
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email-এ পাসওয়ার্ড রিসেট লিংক পাঠানো হয়েছে')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'ইমেইল আবশ্যক';
    if (!value.contains('@') || !value.contains('.')) return 'সঠিক ইমেইল দিন';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'পাসওয়ার্ড আবশ্যক';
    if (_isSignUp) {
      if (value.length < 8) return 'কমপক্ষে ৮ অক্ষর দিন';
      if (!RegExp(r'[0-9]').hasMatch(value)) return 'অন্তত একটি সংখ্যা দিন';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (!_isSignUp) return null;
    if (value != _passwordController.text) return 'পাসওয়ার্ড মিলছে না';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: safeBodyPadding(context, amount: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'বাইতুলমাল কালেকশন ট্র্যাকার',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp ? 'নতুন অ্যাকাউন্ট তৈরি করুন' : 'লগইন করুন',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ইমেইল',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction:
                          _isSignUp ? TextInputAction.next : TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'পাসওয়ার্ড',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: _validatePassword,
                      onFieldSubmitted: (_) {
                        if (!_isSignUp) _submit();
                      },
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'পাসওয়ার্ড নিশ্চিত করুন',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: _validateConfirm,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _submitting ? null : _forgotPassword,
                          child: const Text('পাসওয়ার্ড ভুলে গেছেন?'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'নিবন্ধন করুন' : 'লগইন'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন'
                            : 'নতুন এখানে? অ্যাকাউন্ট তৈরি করুন',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('অথবা'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _signInWithGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text('Google দিয়ে চালিয়ে যান'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
