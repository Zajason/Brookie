import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../services/token_storage.dart';

class SidebarMenu extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final ValueChanged<String> onNavigate; // route name

  const SidebarMenu({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onNavigate,
  });

  final List<AppMenuItem> items = const [
    AppMenuItem(icon: Icons.menu_rounded, label: 'Menu', color: Color(0xFF374151), route: '/'),
    AppMenuItem(icon: Icons.smart_toy_outlined, label: 'AI Assistant', color: Color(0xFF2563EB), route: '/ai'),
    AppMenuItem(icon: Icons.emoji_events_outlined, label: 'Badge library', color: Color(0xFF7C3AED), route: '/badges'),
    AppMenuItem(icon: Icons.leaderboard_rounded, label: 'Leaderboard', color: Color(0xFFF59E0B), route: '/leaderboard'),
    AppMenuItem(icon: Icons.link_rounded, label: 'Link account', color: Color(0xFF16A34A), route: '/link'),
    AppMenuItem(icon: Icons.account_balance_wallet_outlined, label: 'Manage budgets', color: Color(0xFF4F46E5), route: '/budget'),
    AppMenuItem(icon: Icons.receipt_long_outlined, label: 'Scan receipt', color: Color(0xFFEA580C), route: '/scan'),
    AppMenuItem(icon: Icons.logout_rounded, label: 'Log out', color: Color(0xFFDC2626), route: '/logout'),
  ];

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withOpacity(0.20)),
            ),
          ),
        ),

        // Sidebar panel
        Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -1.0, end: 0.0),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, x, child) {
              return Transform.translate(offset: Offset(x * 340, 0), child: child);
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _Panel(
                items: items,
                onClose: onClose,
                onNavigate: onNavigate,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final List<AppMenuItem> items;
  final VoidCallback onClose;
  final ValueChanged<String> onNavigate;

  const _Panel({
    required this.items,
    required this.onClose,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 28, offset: Offset(0, 14)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.close_rounded, size: 22, color: Color(0xFF4B5563)),
                ),
              ),
            ),

            // Header
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 2),
                  Text(
                    "Navigation",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                  SizedBox(height: 10),
                  _GradientBar(),
                  SizedBox(height: 18),
                ],
              ),
            ),

            // Menu items
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 280 + (index * 40)),
                    curve: Curves.easeOut,
                    builder: (context, t, child) {
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(-18 * (1 - t), 0),
                          child: child,
                        ),
                      );
                    },

                    // 🔴 THIS IS THE IMPORTANT PART 🔴
                    child: _MenuRow(
                      item: item,
                      onTap: () async {
                        if (item.route == '/logout') {
                          // ✅ Clear JWT tokens
                          await TokenStorage.clear();

                          // ✅ Close sidebar
                          onClose();

                          // ✅ Go to login and wipe history
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        } else {
                          onNavigate(item.route);
                          onClose();
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Text(
              "Your Account",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final AppMenuItem item;
  final VoidCallback onTap;

  const _MenuRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: item.color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBar extends StatelessWidget {
  const _GradientBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
      ),
    );
  }
}
