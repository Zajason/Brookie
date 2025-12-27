import 'package:flutter/material.dart';
import '../shell/app_shell.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final List<_Category> categories = const [
    _Category(id: 'total', name: 'Total Spending', icon: '💰'),
    _Category(id: 'groceries', name: 'Groceries', icon: '🛒'),
    _Category(id: 'dining', name: 'Dining Out', icon: '🍽️'),
    _Category(id: 'entertainment', name: 'Entertainment', icon: '🎬'),
    _Category(id: 'transport', name: 'Transportation', icon: '🚗'),
    _Category(id: 'shopping', name: 'Shopping', icon: '🛍️'),
  ];

  final Map<String, List<_UserRow>> leaderboardData = const {
    'total': [
      _UserRow(rank: 1, name: 'Sarah Chen', amount: 1842, avatar: '👩🏻'),
      _UserRow(rank: 2, name: 'Michael Brown', amount: 1956, avatar: '👨🏽'),
      _UserRow(rank: 3, name: 'Emma Wilson', amount: 2103, avatar: '👩🏼'),
      _UserRow(rank: 4, name: 'James Lee', amount: 2287, avatar: '👨🏻'),
      _UserRow(rank: 5, name: 'Olivia Garcia', amount: 2401, avatar: '👩🏽'),
      _UserRow(rank: 6, name: 'David Kim', amount: 2556, avatar: '👨🏻'),
      _UserRow(rank: 7, name: 'Sophie Turner', amount: 2689, avatar: '👩🏼'),
      _UserRow(rank: 8, name: 'Ryan Martinez', amount: 2754, avatar: '👨🏽'),
      _UserRow(rank: 9, name: 'Ava Johnson', amount: 2843, avatar: '👩🏻'),
      _UserRow(rank: 10, name: 'Ethan Davis', amount: 2921, avatar: '👨🏼'),
    ],
    'groceries': [
      _UserRow(rank: 1, name: 'Emma Wilson', amount: 234, avatar: '👩🏼'),
      _UserRow(rank: 2, name: 'Sarah Chen', amount: 267, avatar: '👩🏻'),
      _UserRow(rank: 3, name: 'Olivia Garcia', amount: 289, avatar: '👩🏽'),
      _UserRow(rank: 4, name: 'James Lee', amount: 312, avatar: '👨🏻'),
      _UserRow(rank: 5, name: 'Michael Brown', amount: 334, avatar: '👨🏽'),
      _UserRow(rank: 6, name: 'Sophie Turner', amount: 356, avatar: '👩🏼'),
      _UserRow(rank: 7, name: 'David Kim', amount: 378, avatar: '👨🏻'),
      _UserRow(rank: 8, name: 'Ava Johnson', amount: 392, avatar: '👩🏻'),
      _UserRow(rank: 9, name: 'Ryan Martinez', amount: 411, avatar: '👨🏽'),
      _UserRow(rank: 10, name: 'Ethan Davis', amount: 428, avatar: '👨🏼'),
    ],
  };

  final _UserRow currentUserPosition = const _UserRow(rank: 47, name: 'You', amount: 3842, avatar: '👤');

  late _Category selectedCategory;
  bool showCategories = false;

  @override
  void initState() {
    super.initState();
    selectedCategory = categories.first;
  }

  List<_UserRow> get topUsers => leaderboardData[selectedCategory.id] ?? leaderboardData['total']!;

  @override
  Widget build(BuildContext context) {
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
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Leaderboard",
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                            const SizedBox(height: 4),
                            Text("Who's saving the most?", style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFACC15), Color(0xFFF97316)],
                          ),
                        ),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Category filter button
                  InkWell(
                    onTap: () => setState(() => showCategories = !showCategories),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_outlined, color: Color(0xFF4B5563)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "${selectedCategory.icon} ${selectedCategory.name}",
                              style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w500),
                            ),
                          ),
                          AnimatedRotation(
                            turns: showCategories ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(Icons.expand_more_rounded, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dropdown
                  if (showCategories) ...[
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < categories.length; i++) ...[
                            InkWell(
                              onTap: () {
                                setState(() {
                                  selectedCategory = categories[i];
                                  showCategories = false;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                color: selectedCategory.id == categories[i].id ? const Color(0xFFEFF6FF) : Colors.white,
                                child: Row(
                                  children: [
                                    Text(categories[i].icon, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 12),
                                    Text(categories[i].name, style: const TextStyle(color: Color(0xFF111827))),
                                  ],
                                ),
                              ),
                            ),
                            if (i != categories.length - 1) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  for (int i = 0; i < topUsers.length; i++) ...[
                    _LeaderboardRowCard(user: topUsers[i], elevated: i < 3),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 4),
                  _DividerLabel(label: "Your Position"),
                  const SizedBox(height: 12),

                  _CurrentUserCard(user: currentUserPosition),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------ UI Components ------------

class _LeaderboardRowCard extends StatelessWidget {
  final _UserRow user;
  final bool elevated;

  const _LeaderboardRowCard({required this.user, required this.elevated});

  @override
  Widget build(BuildContext context) {
    final medal = _medalStyle(user.rank);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x12000000),
            blurRadius: elevated ? 16 : 10,
            offset: Offset(0, elevated ? 8 : 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: medal.gradient),
            ),
            child: Center(
              child: medal.showTrophy
                  ? const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22)
                  : Text(
                      "${user.rank}",
                      style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.trending_down_rounded, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    const Text("Spent less", style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("\$${user.amount}", style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text("this month", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String label;
  const _DividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFD1D5DB), height: 1)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFD1D5DB), height: 1)),
      ],
    );
  }
}

class _CurrentUserCard extends StatelessWidget {
  final _UserRow user;
  const _CurrentUserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
            ),
            child: Center(
              child: Text("${user.rank}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("You", style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                SizedBox(height: 4),
                Text("Keep improving!", style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("\$${user.amount}", style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text("this month", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// ------------ Helpers / Data ------------

class _Category {
  final String id;
  final String name;
  final String icon;
  const _Category({required this.id, required this.name, required this.icon});
}

class _UserRow {
  final int rank;
  final String name;
  final int amount;
  final String avatar;
  const _UserRow({required this.rank, required this.name, required this.amount, required this.avatar});
}

class _MedalStyle {
  final List<Color> gradient;
  final bool showTrophy;
  const _MedalStyle({required this.gradient, required this.showTrophy});
}

_MedalStyle _medalStyle(int rank) {
  if (rank == 1) {
    return const _MedalStyle(gradient: [Color(0xFFFACC15), Color(0xFFF97316)], showTrophy: true);
  }
  if (rank == 2) {
    return const _MedalStyle(gradient: [Color(0xFFD1D5DB), Color(0xFF9CA3AF)], showTrophy: true);
  }
  if (rank == 3) {
    return const _MedalStyle(gradient: [Color(0xFFFB923C), Color(0xFFEA580C)], showTrophy: true);
  }
  return const _MedalStyle(gradient: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)], showTrophy: false);
}
