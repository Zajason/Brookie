import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/budget_category.dart';
import '../utils/format.dart';

class BudgetWheel extends StatefulWidget {
  final List<BudgetCategory> categories;
  final ValueChanged<String> onCategorySelect;

  const BudgetWheel({
    super.key,
    required this.categories,
    required this.onCategorySelect,
  });

  @override
  State<BudgetWheel> createState() => _BudgetWheelState();
}

class _BudgetWheelState extends State<BudgetWheel> with SingleTickerProviderStateMixin {
  String? selectedId;

  late final AnimationController _controller;
  late Animation<double> _rotationAnim;

  double _currentRotationDeg = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _rotationAnim = AlwaysStoppedAnimation(_currentRotationDeg);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get total => widget.categories.fold(0.0, (s, c) => s + c.amount);

  List<_WheelSegment> get segments {
    double prev = 0.0;
    final out = <_WheelSegment>[];
    for (final c in widget.categories) {
      final start = (prev / total) * 360.0;
      final sweep = (c.amount / total) * 360.0;
      out.add(_WheelSegment(
        category: c,
        startDeg: start,
        sweepDeg: sweep,
        endDeg: start + sweep,
        midDeg: start + sweep / 2.0,
      ));
      prev += c.amount;
    }
    return out;
  }

  void _selectById(String id) {
    final seg = segments.firstWhere((s) => s.category.id == id);

    setState(() => selectedId = id);

    // same idea as React: rotate so selected segment center goes to top
    final targetRotation = -seg.midDeg;
    _animateRotationTo(targetRotation);

    widget.onCategorySelect(id);
  }

  void _animateRotationTo(double targetDeg) {
    _controller.stop();
    _controller.reset();

    double start = _currentRotationDeg;
    double end = targetDeg;

    double delta = (end - start) % 360.0;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    end = start + delta;

    _rotationAnim = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    )..addListener(() => setState(() {}));

    _controller.forward().whenComplete(() {
      _currentRotationDeg = end % 360.0;
    });
  }

  void _handleTapOnWheel(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final v = localPos - center;

    final r = v.distance;
    final outerRadius = size.width * 0.47;
    if (r > outerRadius) return;
    if (r < size.width * 0.19) return;

    double angle = math.atan2(v.dy, v.dx) * 180.0 / math.pi;
    if (angle < 0) angle += 360.0;

    // convert to 0° at 12 o’clock
    final wheelAngle = (angle + 90.0) % 360.0;

    // account for wheel rotation
    final effective = (wheelAngle - _rotationAnim.value) % 360.0;
    final norm = effective < 0 ? effective + 360.0 : effective;

    for (final s in segments) {
      if (norm >= s.startDeg && norm < s.endDeg) {
        _selectById(s.category.id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBudget = widget.categories.fold<double>(0.0, (s, c) => s + c.amount);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, 320.0);
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTapDown: (d) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(d.globalPosition);
                        _handleTapOnWheel(local, Size(size, size));
                      },
                      child: CustomPaint(
                        painter: _BudgetWheelPainter(
                          segments: segments,
                          rotationDeg: _rotationAnim.value,
                          selectedId: selectedId,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -12,
                    left: (size / 2) - 10,
                    child: CustomPaint(
                      size: const Size(20, 12),
                      painter: _TrianglePainter(color: const Color(0xFF1F2937)),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Total Budget", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            "\$${formatNumber(totalBudget)}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final c = widget.categories[index];
              final isSelected = c.id == selectedId;
              final pct = total == 0 ? 0.0 : (c.amount / total) * 100.0;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectById(c.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? c.color.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? c.color : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 2),
                            Text("${pct.toStringAsFixed(1)}%", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WheelSegment {
  final BudgetCategory category;
  final double startDeg, sweepDeg, endDeg, midDeg;

  _WheelSegment({
    required this.category,
    required this.startDeg,
    required this.sweepDeg,
    required this.endDeg,
    required this.midDeg,
  });
}

class _BudgetWheelPainter extends CustomPainter {
  final List<_WheelSegment> segments;
  final double rotationDeg;
  final String? selectedId;

  _BudgetWheelPainter({
    required this.segments,
    required this.rotationDeg,
    required this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final baseRadius = size.width * 0.47;
    final selectedRadius = size.width * 0.50;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_degToRad(rotationDeg));
    canvas.translate(-center.dx, -center.dy);

    for (final seg in segments) {
      final isSelected = seg.category.id == selectedId;
      final r = isSelected ? selectedRadius : baseRadius;

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = seg.category.color.withOpacity(isSelected ? 1.0 : 0.85);

      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white;

      final startRad = _degToRad(-90 + seg.startDeg);
      final sweepRad = _degToRad(seg.sweepDeg);

      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(rect, startRad, sweepRad, true, fill);
      canvas.drawArc(rect, startRad, sweepRad, true, stroke);
    }

    canvas.restore();

    // center circle
    canvas.drawCircle(center, size.width * 0.19, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BudgetWheelPainter oldDelegate) =>
      oldDelegate.rotationDeg != rotationDeg || oldDelegate.selectedId != selectedId;

  double _degToRad(double deg) => deg * math.pi / 180.0;
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => oldDelegate.color != color;
}
