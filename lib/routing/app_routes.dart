import 'package:flutter/material.dart';
import '../screens/budget_wheel_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/badge_library_screen.dart';
import '../screens/scan_reciept_screen.dart' ;
import '../screens/link_account_screen.dart' ;
import '../screens/leaderboard_screen.dart';
import '../screens/ai_chat_screen.dart';

Map<String, WidgetBuilder> appRoutes() {
  return {
    '/': (_) => const BudgetWheelScreen(),
    '/budget': (_) => const BudgetWheelScreen(),
    '/leaderboard': (_) => const LeaderboardScreen(),
   '/ai': (_) => const AiChatScreen(),
    '/badges': (_) => const BadgeLibraryScreen(),
    '/link': (_) => const LinkAccountScreen(),
    '/scan': (_) => const ScanReceiptScreen(),
    '/logout': (_) => const PlaceholderScreen(title: 'Log out'),
  };
}
