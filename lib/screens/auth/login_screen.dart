import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
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

  String _friendlyError(Strings s, FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return s.loginErrorInvalidEmail;
      case 'user-disabled':
        return s.loginErrorUserDisabled;
      case 'user-not-found':
      case 'invalid-credential':
        return s.loginErrorUserNotFound;
      case 'wrong-password':
        return s.loginErrorWrongPassword;
      case 'email-already-in-use':
        return s.loginErrorEmailInUse;
      case 'weak-password':
        return s.loginErrorWeakPassword;
      case 'network-request-failed':
        return s.loginErrorNetwork;
      case 'too-many-requests':
        return s.loginErrorTooManyRequests;
      case 'missing-google-id-token':
        return s.loginErrorMissingGoogleToken;
      case 'no-current-user':
        return s.loginErrorNoCurrentUser;
      case 'missing-password':
        return s.loginErrorMissingPassword;
      default:
        return e.message ?? s.loginErrorGeneric;
    }
  }

  Future<void> _submit(Strings s) async {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(s, e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInWithGoogle(Strings s) async {
    setState(() => _submitting = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(s, e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.loginGoogleSignInFailed('$e'))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword(Strings s) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.loginEnterEmailFirst)));
      return;
    }
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loginResetLinkSent(email))),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyError(s, e))));
    }
  }

  String? _validateEmail(Strings s, String? value) {
    if (value == null || value.trim().isEmpty) return s.loginEmailRequired;
    if (!value.contains('@') || !value.contains('.')) return s.loginEmailInvalid;
    return null;
  }

  String? _validatePassword(Strings s, String? value) {
    if (value == null || value.isEmpty) return s.loginPasswordRequired;
    if (_isSignUp) {
      if (value.length < 8) return s.loginPasswordTooShort;
      if (!RegExp(r'[0-9]').hasMatch(value)) return s.loginPasswordNeedsDigit;
    }
    return null;
  }

  String? _validateConfirm(Strings s, String? value) {
    if (!_isSignUp) return null;
    if (value != _passwordController.text) return s.loginPasswordMismatch;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
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
                      s.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp ? s.loginSignUpTitle : s.loginSignInTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: s.loginEmail,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) => _validateEmail(s, v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction:
                          _isSignUp ? TextInputAction.next : TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: s.loginPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => _validatePassword(s, v),
                      onFieldSubmitted: (_) {
                        if (!_isSignUp) _submit(s);
                      },
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: s.loginConfirmPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        validator: (v) => _validateConfirm(s, v),
                        onFieldSubmitted: (_) => _submit(s),
                      ),
                    ],
                    if (!_isSignUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _submitting ? null : () => _forgotPassword(s),
                          child: Text(s.loginForgotPassword),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _submitting ? null : () => _submit(s),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? s.loginSignUpButton : s.loginSignInButton),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp ? s.loginHaveAccount : s.loginNewHere),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(s.loginOr),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : () => _signInWithGoogle(s),
                      icon: const Icon(Icons.login),
                      label: Text(s.loginWithGoogle),
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
