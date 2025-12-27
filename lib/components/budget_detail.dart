import 'package:flutter/material.dart';
import '../models/budget_category.dart';
import '../utils/format.dart';

class BudgetDetailCard extends StatelessWidget {
  final BudgetCategory category;

  const BudgetDetailCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final percentage = category.percentageUsed;
    final remaining = category.remaining;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.name,
                style: TextStyle(fontSize: 13, color: category.color, fontWeight: FontWeight.w500),
              ),
              Text(
                "${percentage.toStringAsFixed(1)}% used",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _AnimatedProgressBar(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            color: category.color,
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _kvInline("Spent:", "\$${formatNumber(category.spent)}"),
              _kvInline("Budget:", "\$${formatNumber(category.budget)}"),
            ],
          ),
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                children: [
                  TextSpan(text: "Remaining: ", style: TextStyle(color: Colors.grey.shade600)),
                  TextSpan(
                    text: "\$${formatNumber(remaining.abs())}${remaining < 0 ? " over" : ""}",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // AI insight block
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AI Insight", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(
                        category.aiComment,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _kvInline(String k, String v) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
        children: [
          TextSpan(text: "$k ", style: TextStyle(color: Colors.grey.shade600)),
          TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Color color;

  const _AnimatedProgressBar({required this.value, required this.color});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _a = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOut),
    )..addListener(() => setState(() {}));
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value - widget.value).abs() > 0.0001) {
      _c.stop();
      _c.reset();
      _a = Tween<double>(begin: 0, end: widget.value).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOut),
      )..addListener(() => setState(() {}));
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _a.value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
