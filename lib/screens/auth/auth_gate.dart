import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../protisthan_list_screen.dart';
import 'login_screen.dart';

/// The app's root widget — shows [LoginScreen] until someone is signed in,
/// then [ProtisthanListScreen]. Rebuilds automatically on every sign-in/
/// sign-out via [AuthService.authStateChanges].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const ProtisthanListScreen();
      },
    );
  }
}
