import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Always starts at the LoginScreen.
/// The user must actively sign in each session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
