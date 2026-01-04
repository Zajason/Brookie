import 'package:flutter/material.dart';
import 'routing/app_routes.dart';

void main() {
  runApp(const BrookieApp());
}

class BrookieApp extends StatelessWidget {
  const BrookieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',          // ✅ start here
      routes: appRoutes(),        // ✅ keep your existing named routes
    );
  }
}
