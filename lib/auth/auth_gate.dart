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
    final access = await TokenStorage.getAccessToken();
    final refresh = await TokenStorage.getRefreshToken();
    final loggedIn = (access != null && access.isNotEmpty) &&
        (refresh != null && refresh.isNotEmpty);

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
