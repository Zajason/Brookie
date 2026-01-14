import 'package:flutter/material.dart';
import '../services/token_storage.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    bool loggedIn = false;
    
    try {
      final access = await TokenStorage.getAccessToken()
          .timeout(const Duration(seconds: 2));
      final refresh = await TokenStorage.getRefreshToken()
          .timeout(const Duration(seconds: 2));
      loggedIn = (access != null && access.isNotEmpty) &&
          (refresh != null && refresh.isNotEmpty);
    } catch (e) {
      // Timeout or error - go to login
      loggedIn = false;
    }

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      loggedIn ? '/budget' : '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
