import 'dart:ui';
import 'package:flutter/material.dart';
import '../components/sidebar_menu.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  /// If true, content is wrapped in SafeArea.
  /// If false, content can render under the notch/status bar (full-bleed).
  final bool safeArea;

  const AppShell({
    super.key,
    required this.child,
    this.safeArea = false, // ✅ default full-bleed
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool isOpen = false;

  void _navigate(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Notch/status bar height
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true, // ✅ allows under status bar
          body: Stack(
            children: [
              widget.safeArea
                  ? SafeArea(child: widget.child)
                  : widget.child,

              // ✅ Burger button TOP-LEFT
              Positioned(
                top: 8 + (widget.safeArea ? 0 : topInset),
                left: 8,
                child: _BurgerButton(
                  onTap: () => setState(() => isOpen = true),
                ),
              ),
            ],
          ),
        ),

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.menu_rounded, size: 22, color: Color(0xFF111827)),
            ),
          ),
        ),
      ),
    );
  }
}
