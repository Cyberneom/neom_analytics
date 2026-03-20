import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:sint/sint.dart';

/// Data class for Year Wrap content.
class YearWrapData {
  final int year;
  final String userName;
  final String userPhotoUrl;

  /// Reading or listening total (pages or seconds)
  final int totalEngagement;
  final String engagementLabel; // e.g. "páginas leídas" or "segundos escuchados"
  final String engagementIcon; // 'reading' or 'listening'

  /// Total sessions
  final int totalSessions;

  /// Unique items consumed (books or tracks)
  final int uniqueItems;
  final String itemsLabel; // e.g. "libros" or "temas"

  /// Streaks
  final int longestStreak;

  /// Top item
  final String topItemName;
  final int topItemEngagement;

  /// Top creator
  final String topCreatorName;
  final int topCreatorEngagement;

  /// Fan tier (highest achieved)
  final String? highestFanTier; // 'superfan', 'fan', 'supporter', null

  /// Monthly distribution (1-12)
  final Map<int, int> monthlyEngagement;

  /// Best month
  final int bestMonth;
  final int bestMonthValue;

  const YearWrapData({
    required this.year,
    required this.userName,
    this.userPhotoUrl = '',
    required this.totalEngagement,
    required this.engagementLabel,
    this.engagementIcon = 'reading',
    required this.totalSessions,
    required this.uniqueItems,
    required this.itemsLabel,
    required this.longestStreak,
    required this.topItemName,
    required this.topItemEngagement,
    required this.topCreatorName,
    required this.topCreatorEngagement,
    this.highestFanTier,
    required this.monthlyEngagement,
    required this.bestMonth,
    required this.bestMonthValue,
  });
}

/// Year Wrap page — a shareable annual summary (like Spotify Wrapped).
///
/// Pass [YearWrapData] to render either reading or listening wrap.
class YearWrapPage extends StatelessWidget {

  final YearWrapData data;

  const YearWrapPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: SintAppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: 'Tu ${data.year}',
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share screenshot
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            _buildHeroSection(),
            const SizedBox(height: 32),
            _buildStatsGrid(),
            const SizedBox(height: 32),
            _buildTopItemCard(),
            const SizedBox(height: 16),
            _buildTopCreatorCard(),
            if (data.highestFanTier != null) ...[
              const SizedBox(height: 16),
              _buildFanTierCard(),
            ],
            const SizedBox(height: 32),
            _buildMonthlyChart(),
            const SizedBox(height: 32),
            _buildStreakCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final isReading = data.engagementIcon == 'reading';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isReading
              ? [const Color(0xFF1A237E), const Color(0xFF4A148C)]
              : [const Color(0xFF880E4F), const Color(0xFFE65100)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            isReading ? Icons.auto_stories : Icons.headphones,
            size: 48,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatLargeNumber(data.totalEngagement)}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          Text(
            data.engagementLabel,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'en ${data.year}',
            style: const TextStyle(fontSize: 14, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        _buildStatTile(Icons.event_note, '${data.totalSessions}', 'sesiones'),
        const SizedBox(width: 12),
        _buildStatTile(
          data.engagementIcon == 'reading' ? Icons.menu_book : Icons.library_music,
          '${data.uniqueItems}',
          data.itemsLabel,
        ),
        const SizedBox(width: 12),
        _buildStatTile(Icons.local_fire_department, '${data.longestStreak}', 'mejor racha'),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColor.bondiBlue, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItemCard() {
    return _buildHighlightCard(
      icon: Icons.star,
      color: const Color(0xFFFFD700),
      title: 'Tu favorito',
      value: data.topItemName,
      subtitle: '${_formatLargeNumber(data.topItemEngagement)} ${data.engagementLabel}',
    );
  }

  Widget _buildTopCreatorCard() {
    return _buildHighlightCard(
      icon: Icons.person,
      color: const Color(0xFFE91E63),
      title: data.engagementIcon == 'reading' ? 'Tu autor favorito' : 'Tu artista favorito',
      value: data.topCreatorName,
      subtitle: '${_formatLargeNumber(data.topCreatorEngagement)} ${data.engagementLabel}',
    );
  }

  Widget _buildFanTierCard() {
    final tierName = data.highestFanTier ?? '';
    final tierColor = tierName == 'superfan'
        ? const Color(0xFFFFD700)
        : tierName == 'fan'
            ? const Color(0xFFE91E63)
            : AppColor.bondiBlue;

    return _buildHighlightCard(
      icon: tierName == 'superfan' ? Icons.star : Icons.favorite,
      color: tierColor,
      title: 'Tu nivel mas alto',
      value: tierName[0].toUpperCase() + tierName.substring(1),
      subtitle: 'Eres parte de los mas dedicados',
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(40),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    int maxVal = 0;
    data.monthlyEngagement.forEach((_, v) { if (v > maxVal) maxVal = v; });
    if (maxVal == 0) maxVal = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tu actividad mensual', style: TextStyle(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (i) {
              final month = i + 1;
              final val = data.monthlyEngagement[month] ?? 0;
              final ratio = val / maxVal;
              final isBest = month == data.bestMonth;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: ratio.clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isBest ? const Color(0xFFFFD700) : AppColor.bondiBlue,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(months[i], style: TextStyle(
                        fontSize: 8,
                        color: isBest ? const Color(0xFFFFD700) : Colors.white38,
                        fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                      )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${data.longestStreak} dias', style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900,
              )),
              const Text('Tu mejor racha del año', style: TextStyle(
                color: Colors.white70, fontSize: 12,
              )),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLargeNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
