import 'package:flutter/material.dart';
import '../shell/app_shell.dart';
import '../models/budget_settings_item.dart';
import '../services/budget_service.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  bool loading = true;
  String? error;

  // ✅ Fixed categories (includes Entertainment so it matches backend categories)
  late List<BudgetSettingsItem> items = [
    BudgetSettingsItem(
      key: 'rent',
      label: 'Rent',
      icon: '🏠',
      gradient: const [Color(0xFF60A5FA), Color(0xFF6366F1)],
      limit: 0,
      spent: 0,
    ),
    BudgetSettingsItem(
      key: 'groceries',
      label: 'Groceries',
      icon: '🛒',
      gradient: const [Color(0xFF34D399), Color(0xFF10B981)],
      limit: 0,
      spent: 0,
    ),
    BudgetSettingsItem(
      key: 'utilities',
      label: 'Utilities',
      icon: '💡',
      gradient: const [Color(0xFFFBBF24), Color(0xFFF97316)],
      limit: 0,
      spent: 0,
    ),
    BudgetSettingsItem(
      key: 'entertainment',
      label: 'Entertainment',
      icon: '🎉',
      gradient: const [Color(0xFFA78BFA), Color(0xFFEC4899)],
      limit: 0,
      spent: 0,
    ),
    BudgetSettingsItem(
      key: 'healthcare',
      label: 'Healthcare',
      icon: '🏥',
      gradient: const [Color(0xFFF87171), Color(0xFFEC4899)],
      limit: 0,
      spent: 0,
    ),
    BudgetSettingsItem(
      key: 'transportation',
      label: 'Transportation',
      icon: '🚗',
      gradient: const [Color(0xFF22D3EE), Color(0xFF3B82F6)],
      limit: 0,
      spent: 0,
    ),
    BudgetSettingsItem(
      key: 'savings',
      label: 'Savings',
      icon: '💰',
      gradient: const [Color(0xFF818CF8), Color(0xFF4F46E5)],
      limit: 0,
      spent: 0,
    ),
    BudgetSettingsItem(
      key: 'other',
      label: 'Other',
      icon: '📦',
      gradient: const [Color(0xFF9CA3AF), Color(0xFF64748B)],
      limit: 0,
      spent: 0,
    ),
  ];

  double get totalBudget => items.fold(0.0, (s, i) => s + i.limit);
  double get totalSpent => items.fold(0.0, (s, i) => s + i.spent);

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
      final budgets = await BudgetService.fetchBudgets();
      final spending = await BudgetService.fetchSpending();

      final budgetMap = <String, double>{};
      for (final b in budgets) {
        final key = (b['category'] ?? '').toString();
        final amt = double.tryParse((b['amount'] ?? '0').toString()) ?? 0.0;
        budgetMap[key] = amt;
      }

      final spendMap = <String, double>{};
      for (final s in spending) {
        final key = (s['category'] ?? '').toString();
        final amt = double.tryParse((s['amount'] ?? '0').toString()) ?? 0.0;
        spendMap[key] = amt;
      }

      for (final it in items) {
        it.limit = budgetMap[it.key] ?? 0.0;
        it.spent = spendMap[it.key] ?? 0.0;
      }

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _openEditSheet(BudgetSettingsItem item) async {
    final controller = TextEditingController(
      text: item.limit > 0 ? item.limit.toStringAsFixed(0) : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: item.gradient,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10)),
                      ],
                    ),
                    child: Center(child: Text(item.icon, style: const TextStyle(fontSize: 30))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        const SizedBox(height: 4),
                        Text("Set your monthly budget limit",
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Align(
                alignment: Alignment.centerLeft,
                child: Text("Monthly Limit",
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  hintText: '0',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text("Quick select:", style: TextStyle(color: Colors.grey.shade600)),
              ),
              const SizedBox(height: 10),

              GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [100, 250, 500, 1000].map((amt) {
                  return InkWell(
                    onTap: () => controller.text = amt.toString(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text('\$$amt', style: const TextStyle(color: Color(0xFF374151)))),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF374151),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final raw = controller.text.trim();
                        final val = double.tryParse(raw);
                        if (val == null || val < 0) return;

                        try {
                          await BudgetService.updateBudget(categoryKey: item.key, amount: val);
                          if (!mounted) return;
                          setState(() => item.limit = val);
                          Navigator.pop(ctx);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text("Save Budget", style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(56, 76, 20, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                  boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 10))],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.chevron_left_rounded, size: 28, color: Color(0xFF374151)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Center(
                            child: Text("Budget Settings",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                          ),
                        ),
                        const SizedBox(width: 36), // spacing like React
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Total summary card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.trending_up_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text("Total Monthly Budget",
                                  style: TextStyle(color: Color(0xDFFFFFFF), fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("\$", style: TextStyle(color: Colors.white, fontSize: 18)),
                              const SizedBox(width: 4),
                              Text(totalBudget.toStringAsFixed(0),
                                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "\$${totalSpent.toStringAsFixed(0)} spent • \$${(totalBudget - totalSpent).toStringAsFixed(0)} remaining",
                            style: const TextStyle(color: Color(0xCCFFFFFF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : (error != null)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                                  const SizedBox(height: 10),
                                  Text(error!, textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _load,
                                    child: const Text("Retry"),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final it = items[i];

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 8)),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: it.gradient,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
                                              ],
                                            ),
                                            child: Center(child: Text(it.icon, style: const TextStyle(fontSize: 24))),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(it.label,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                                                if (it.limit > 0)
                                                  Text(
                                                    "\$${it.spent.toStringAsFixed(0)} / \$${it.limit.toStringAsFixed(0)}",
                                                    style: TextStyle(color: Colors.grey.shade600),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (it.limit > 0) ...[
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            minHeight: 8,
                                            value: (it.spent / it.limit).clamp(0.0, 1.0),
                                            backgroundColor: const Color(0xFFF3F4F6),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              it.overBudget ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ),
                                        if (it.overBudget) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.error_outline, size: 18, color: Color(0xFFEF4444)),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Over budget by \$${(it.spent - it.limit).toStringAsFixed(0)}",
                                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],

                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Text("Monthly limit:", style: TextStyle(color: Colors.grey.shade700)),
                                          const SizedBox(width: 10),
                                          InkWell(
                                            onTap: () => _openEditSheet(it),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9FAFB),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.attach_money_rounded, size: 18, color: Color(0xFF6B7280)),
                                                  Text(
                                                    it.limit > 0 ? it.limit.toStringAsFixed(0) : "Not set",
                                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    it.limit > 0 ? "Edit" : "Set",
                                                    style: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
