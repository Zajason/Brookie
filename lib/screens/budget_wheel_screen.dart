import 'package:flutter/material.dart';
import '../components/budget_detail.dart';
import '../components/budget_wheel.dart';
import '../models/budget_category.dart';

class BudgetWheelScreen extends StatefulWidget {
  const BudgetWheelScreen({super.key});

  @override
  State<BudgetWheelScreen> createState() => _BudgetWheelScreenState();
}

class _BudgetWheelScreenState extends State<BudgetWheelScreen> {
  BudgetCategory? selected;

  final List<BudgetCategory> budgetData = const [
    BudgetCategory(
      id: '1',
      name: 'Rent',
      amount: 1500,
      color: Color(0xFF3B82F6),
      budget: 1500,
      spent: 1500,
      aiComment:
          "You're right on track with your rent budget. Your housing costs are 28% of your income, which is within the recommended range.",
    ),
    BudgetCategory(
      id: '2',
      name: 'Utilities',
      amount: 300,
      color: Color(0xFFEF4444),
      budget: 350,
      spent: 280,
      aiComment:
          "Great job! You've spent 20% less than your budget on utilities. Consider the savings from energy-efficient appliances.",
    ),
    BudgetCategory(
      id: '3',
      name: 'Entertainment',
      amount: 400,
      color: Color(0xFF8B5CF6),
      budget: 350,
      spent: 448,
      aiComment:
          "You've spent 12% more than your peers in this area. Consider setting spending limits for dining out and streaming services.",
    ),
    BudgetCategory(
      id: '4',
      name: 'Groceries',
      amount: 600,
      color: Color(0xFF10B981),
      budget: 650,
      spent: 520,
      aiComment:
          "You're doing well! Your grocery spending is 8% below budget. Meal planning seems to be working for you.",
    ),
    BudgetCategory(
      id: '5',
      name: 'Transportation',
      amount: 350,
      color: Color(0xFFF59E0B),
      budget: 400,
      spent: 365,
      aiComment:
          "Your transportation costs are 9% below budget. Your peers spend about the same. Consider carpooling to save even more.",
    ),
    BudgetCategory(
      id: '6',
      name: 'Savings',
      amount: 500,
      color: Color(0xFF06B6D4),
      budget: 500,
      spent: 500,
      aiComment:
          "Excellent! You're meeting your savings goal. You're saving 15% more than the average person in your age group.",
    ),
    BudgetCategory(
      id: '7',
      name: 'Healthcare',
      amount: 250,
      color: Color(0xFFEC4899),
      budget: 300,
      spent: 185,
      aiComment:
          "Your healthcare spending is 38% below budget. Make sure you're not skipping important preventive care appointments.",
    ),
    BudgetCategory(
      id: '8',
      name: 'Other',
      amount: 200,
      color: Color(0xFF6366F1),
      budget: 250,
      spent: 212,
      aiComment:
          "Your miscellaneous spending is within range, just 15% below budget. Good job tracking those small expenses!",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text("Budget Wheel",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      "Click on any segment to see insights",
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    BudgetWheel(
                      categories: budgetData,
                      onCategorySelect: (id) {
                        setState(() {
                          selected = budgetData.firstWhere((c) => c.id == id);
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    if (selected != null)
                      BudgetDetailCard(category: selected!)
                    else
                      const _SelectCategoryPlaceholder(),
                  ],
                ),
              ),
            ),
          ),
        ),
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
