import 'dart:math';
import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:sint/sint.dart';

/// Input data for taste compatibility calculation.
class TasteProfile {
  final String userId;
  final String userName;
  final String photoUrl;
  /// Map of itemId → engagement value
  final Map<String, int> itemEngagement;
  /// Map of creatorEmail → engagement value
  final Map<String, int> creatorEngagement;

  const TasteProfile({
    required this.userId,
    required this.userName,
    this.photoUrl = '',
    required this.itemEngagement,
    required this.creatorEngagement,
  });
}

/// Result of compatibility analysis between two users.
class CompatibilityResult {
  /// 0.0 to 1.0
  final double overallScore;
  /// Shared items
  final List<String> sharedItems;
  /// Shared creators
  final List<String> sharedCreators;
  /// Category label
  final String category;

  const CompatibilityResult({
    required this.overallScore,
    required this.sharedItems,
    required this.sharedCreators,
    required this.category,
  });

  /// Calculate compatibility between two taste profiles.
  static CompatibilityResult calculate(TasteProfile a, TasteProfile b) {
    // Shared items
    final sharedItemIds = a.itemEngagement.keys.toSet().intersection(b.itemEngagement.keys.toSet());
    final sharedCreatorIds = a.creatorEngagement.keys.toSet().intersection(b.creatorEngagement.keys.toSet());

    // Cosine similarity on item engagement vectors
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;
    final allItems = {...a.itemEngagement.keys, ...b.itemEngagement.keys};
    for (final item in allItems) {
      final va = (a.itemEngagement[item] ?? 0).toDouble();
      final vb = (b.itemEngagement[item] ?? 0).toDouble();
      dotProduct += va * vb;
      normA += va * va;
      normB += vb * vb;
    }
    double itemSimilarity = (normA > 0 && normB > 0)
        ? dotProduct / (sqrt(normA) * sqrt(normB))
        : 0.0;

    // Creator overlap ratio
    final allCreators = {...a.creatorEngagement.keys, ...b.creatorEngagement.keys};
    double creatorOverlap = allCreators.isNotEmpty
        ? sharedCreatorIds.length / allCreators.length
        : 0.0;

    // Overall: weighted average
    double overall = (itemSimilarity * 0.6 + creatorOverlap * 0.4).clamp(0.0, 1.0);

    String category;
    if (overall >= 0.8) {
      category = 'Almas gemelas';
    } else if (overall >= 0.6) {
      category = 'Muy compatibles';
    } else if (overall >= 0.4) {
      category = 'Intereses comunes';
    } else if (overall >= 0.2) {
      category = 'Gustos diferentes';
    } else {
      category = 'Mundos distintos';
    }

    return CompatibilityResult(
      overallScore: overall,
      sharedItems: sharedItemIds.toList(),
      sharedCreators: sharedCreatorIds.toList(),
      category: category,
    );
  }
}

/// Page showing taste compatibility between the current user and another.
class TasteCompatibilityPage extends StatelessWidget {

  final TasteProfile userProfile;
  final TasteProfile otherProfile;
  final String engagementLabel; // "libros" or "temas"
  final Map<String, String> itemNames; // itemId → display name

  const TasteCompatibilityPage({
    super.key,
    required this.userProfile,
    required this.otherProfile,
    this.engagementLabel = 'items',
    this.itemNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    final result = CompatibilityResult.calculate(userProfile, otherProfile);
    final pct = (result.overallScore * 100).toInt();
    final color = _scoreColor(result.overallScore);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: SintAppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: 'Compatibilidad',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAvatar(userProfile),
                const SizedBox(width: 16),
                Icon(Icons.favorite, color: color, size: 28),
                const SizedBox(width: 16),
                _buildAvatar(otherProfile),
              ],
            ),
            const SizedBox(height: 24),

            // Score ring
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: result.overallScore,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withAlpha(20),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$pct%', style: TextStyle(
                        color: color, fontSize: 42, fontWeight: FontWeight.w900,
                      )),
                      Text(result.category, style: const TextStyle(
                        color: Colors.white54, fontSize: 12,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                _buildStatCard(Icons.library_books, '${result.sharedItems.length}', '$engagementLabel en comun', color),
                const SizedBox(width: 12),
                _buildStatCard(Icons.person, '${result.sharedCreators.length}', 'creadores en comun', color),
              ],
            ),
            const SizedBox(height: 24),

            // Shared items list
            if (result.sharedItems.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('En comun', style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
                )),
              ),
              AppTheme.heightSpace10,
              ...result.sharedItems.take(10).map((itemId) {
                final name = itemNames[itemId] ?? itemId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(TasteProfile profile) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white.withAlpha(20),
          backgroundImage: profile.photoUrl.isNotEmpty ? NetworkImage(profile.photoUrl) : null,
          child: profile.photoUrl.isEmpty
              ? Text(profile.userName.isNotEmpty ? profile.userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 22))
              : null,
        ),
        const SizedBox(height: 6),
        Text(profile.userName.split('@').first, style: const TextStyle(
          color: Colors.white54, fontSize: 11,
        )),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.8) return const Color(0xFF4CAF50);
    if (score >= 0.6) return AppColor.bondiBlue;
    if (score >= 0.4) return const Color(0xFFFF9800);
    if (score >= 0.2) return const Color(0xFFE91E63);
    return Colors.grey;
  }
}
