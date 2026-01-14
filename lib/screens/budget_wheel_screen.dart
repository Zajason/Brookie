import 'package:flutter/material.dart';
import '../shell/app_shell.dart';
import '../components/budget_wheel.dart';
import '../components/budget_detail.dart';
import '../models/budget_category.dart';
import '../services/budget_wheel_service.dart';

class BudgetWheelScreen extends StatefulWidget {
  const BudgetWheelScreen({super.key});

  @override
  State<BudgetWheelScreen> createState() => _BudgetWheelScreenState();
}

class _BudgetWheelScreenState extends State<BudgetWheelScreen> {
  BudgetCategory? selected;

  bool loading = true;
  String? error;
  List<BudgetCategory> categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await BudgetWheelService.fetchCategories();
      if (!mounted) return;

      setState(() {
        categories = data;
        loading = false;

        // keep selection if possible
        if (selected != null) {
          final match = data.where((c) => c.id == selected!.id).toList();
          selected = match.isNotEmpty ? match.first : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(56, 76, 16, 20),
              child: Column(
                children: [
                  const Text("Budget Wheel",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    "Click on any segment to see insights",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  if (loading) ...[
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text("Loading your budgets...",
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 30),
                  ] else if (error != null) ...[
                    _ErrorCard(
                      message: error!,
                      onRetry: _load,
                    ),
                  ] else if (categories.isEmpty) ...[
                    _ErrorCard(
                      message: "No categories returned from server.",
                      onRetry: _load,
                    ),
                  ] else ...[
                    BudgetWheel(
                      categories: categories,
                      onCategorySelect: (id) {
                        setState(() => selected = categories.firstWhere((c) => c.id == id));
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selected != null)
                      BudgetDetailCard(category: selected!)
                    else
                      const _SelectCategoryPlaceholder(),
                  ],

                  const SizedBox(height: 16),

                  // optional manual refresh
                  if (!loading)
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh"),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 42, color: Colors.red.shade300),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text("Retry"),
          )
        ],
      ),
    );
  }
}

class _SelectCategoryPlaceholder extends StatelessWidget {
  const _SelectCategoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            "Select a category to view insights",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
