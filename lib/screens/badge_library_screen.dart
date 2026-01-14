import 'package:flutter/material.dart';
import '../shell/app_shell.dart';
import '../models/badge.dart';


class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: badge.earned ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            // ICON
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: badge.gradient,
                ),
              ),
              child: Icon(badge.icon, color: Colors.white, size: 32),
            ),

            const SizedBox(height: 12),

            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 6),

            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const Spacer(),

            // PROGRESS
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: badge.gradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcIn,
                    child: LinearProgressIndicator(
                      value: badge.progress / 100,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      badge.requirement,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    if (badge.earned)
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 16),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class BadgeLibraryScreen extends StatelessWidget {
  const BadgeLibraryScreen({super.key});

  static const List<BadgeModel> badges = [
    BadgeModel(
      id: 1,
      title: 'Budget Master',
      description: 'Stayed within grocery budget for a month',
      icon: Icons.restaurant_rounded,
      progress: 100,
      earned: true,
      gradient: [Color(0xFF4ADE80), Color(0xFF10B981)],
      requirement: '30/30 days',
    ),
    BadgeModel(
      id: 2,
      title: 'Savings Champion',
      description: 'Spent less than peers for a full year',
      icon: Icons.emoji_events_rounded,
      progress: 100,
      earned: true,
      gradient: [Color(0xFFFACC15), Color(0xFFF97316)],
      requirement: '12/12 months',
    ),
    BadgeModel(
      id: 3,
      title: 'Thrifty Shopper',
      description: 'Stayed within shopping budget for a month',
      icon: Icons.auto_awesome_rounded,
      progress: 73,
      earned: false,
      gradient: [Color(0xFFC084FC), Color(0xFFEC4899)],
      requirement: '22/30 days',
    ),
    BadgeModel(
      id: 4,
      title: 'Goal Crusher',
      description: 'Met your monthly savings goal',
      icon: Icons.track_changes_rounded,
      progress: 45,
      earned: false,
      gradient: [Color(0xFF60A5FA), Color(0xFF22D3EE)],
      requirement: '\$450/\$1000',
    ),
    BadgeModel(
      id: 5,
      title: 'Spending Slayer',
      description: 'Reduced spending by 20% this month',
      icon: Icons.trending_down_rounded,
      progress: 60,
      earned: false,
      gradient: [Color(0xFFF87171), Color(0xFFFB7185)],
      requirement: '12% reduced',
    ),
    BadgeModel(
      id: 6,
      title: 'Elite Saver',
      description: 'Beat peer average spending 6 months in a row',
      icon: Icons.workspace_premium_rounded,
      progress: 33,
      earned: false,
      gradient: [Color(0xFF818CF8), Color(0xFFA855F7)],
      requirement: '2/6 months',
    ),
    BadgeModel(
      id: 7,
      title: 'Social Saver',
      description: 'Stayed within entertainment budget for a month',
      icon: Icons.people_alt_rounded,
      progress: 0,
      earned: false,
      gradient: [Color(0xFF2DD4BF), Color(0xFF22C55E)],
      requirement: '0/30 days',
    ),
    BadgeModel(
      id: 8,
      title: 'Year Legend',
      description: 'Stayed within total budget for 365 days',
      icon: Icons.calendar_month_rounded,
      progress: 0,
      earned: false,
      gradient: [Color(0xFFFB923C), Color(0xFFEF4444)],
      requirement: '0/365 days',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final earnedCount = badges.where((b) => b.earned).length;
    final overallProgress = earnedCount / badges.length;

    return AppShell(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF9FAFB)],
          ),
        ),
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 76, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Badge Library',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$earnedCount of ${badges.length} badges earned',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BADGE GRID
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  return _BadgeCard(badge: badges[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  
}
