import 'package:flutter/material.dart';
import '../shell/app_shell.dart';
import '../services/badge_service.dart';

// Map icon names from backend to Flutter IconData
IconData _getIconFromName(String iconName) {
  final iconMap = {
    'restaurant_rounded': Icons.restaurant_rounded,
    'emoji_events_rounded': Icons.emoji_events_rounded,
    'auto_awesome_rounded': Icons.auto_awesome_rounded,
    'track_changes_rounded': Icons.track_changes_rounded,
    'trending_down_rounded': Icons.trending_down_rounded,
    'workspace_premium_rounded': Icons.workspace_premium_rounded,
    'people_alt_rounded': Icons.people_alt_rounded,
    'calendar_month_rounded': Icons.calendar_month_rounded,
  };
  return iconMap[iconName] ?? Icons.star_rounded;
}

// Parse hex color string to Color
Color _parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

class _BadgeCard extends StatelessWidget {
  final BadgeData badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      _parseColor(badge.gradientStart),
      _parseColor(badge.gradientEnd),
    ];
    
    // Unfinished badges are more visible now (0.7 instead of 0.4)
    // Icon gets slightly desaturated for unearned badges
    final iconOpacity = badge.earned ? 1.0 : 0.6;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: badge.earned ? gradientColors[0].withOpacity(0.3) : const Color(0xFFF3F4F6),
          width: badge.earned ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: badge.earned ? gradientColors[0].withOpacity(0.15) : const Color(0x08000000),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ICON
          Opacity(
            opacity: iconOpacity,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: badge.earned 
                      ? gradientColors 
                      : [Colors.grey.shade400, Colors.grey.shade500],
                ),
              ),
              child: Icon(_getIconFromName(badge.icon), color: Colors.white, size: 32),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: badge.earned ? Colors.black : Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const Spacer(),

          // PROGRESS BAR
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // Background track
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  // Progress fill with gradient
                  FractionallySizedBox(
                    widthFactor: (badge.progress / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
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
    );
  }
}


class BadgeLibraryScreen extends StatefulWidget {
  const BadgeLibraryScreen({super.key});

  @override
  State<BadgeLibraryScreen> createState() => _BadgeLibraryScreenState();
}

class _BadgeLibraryScreenState extends State<BadgeLibraryScreen> {
  List<BadgeData> _badges = [];
  int _earnedCount = 0;
  int _totalCount = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await BadgeService.fetchBadges();
      setState(() {
        _badges = response.badges;
        _earnedCount = response.earnedCount;
        _totalCount = response.totalCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final overallProgress = _totalCount > 0 ? _earnedCount / _totalCount : 0.0;

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
                    '$_earnedCount of $_totalCount badges earned',
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

            // CONTENT
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load badges',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loadBadges,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _badges.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No badges available yet',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadBadges,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: _badges.length,
                                itemBuilder: (context, index) {
                                  return _BadgeCard(badge: _badges[index]);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
