import 'package:flutter/material.dart';
import '../components/sidebar_menu.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String title; // optional; you can ignore
  const AppShell({super.key, required this.child, this.title = ""});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool isOpen = false;

  void _navigate(String route) {
    // Avoid pushing duplicate route
    if (ModalRoute.of(context)?.settings.name == route) return;

    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Screen
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                widget.child,

                // Top-right burger button (always)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _BurgerButton(
                    onTap: () => setState(() => isOpen = true),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sidebar overlay
        SidebarMenu(
          isOpen: isOpen,
          onClose: () => setState(() => isOpen = false),
          onNavigate: _navigate,
        ),
      ],
    );
  }
}

class _BurgerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BurgerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.menu_rounded, size: 22, color: Color(0xFF111827)),
        ),
      ),
    );
  }
}
