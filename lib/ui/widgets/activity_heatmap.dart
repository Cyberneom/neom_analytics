import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';

/// GitHub-style activity heatmap showing daily engagement.
///
/// [dailyValues] maps DateTime (date only) to engagement value.
/// Renders last [weeks] weeks of data in a grid.
class ActivityHeatmap extends StatelessWidget {

  final Map<DateTime, int> dailyValues;
  final int weeks;
  final String label; // e.g. "Actividad de lectura" or "Actividad de escucha"
  final Color activeColor;

  const ActivityHeatmap({
    super.key,
    required this.dailyValues,
    this.weeks = 20,
    this.label = 'Actividad',
    this.activeColor = AppColor.bondiBlue,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Find max value for intensity scaling
    int maxVal = 0;
    dailyValues.forEach((_, v) { if (v > maxVal) maxVal = v; });
    if (maxVal == 0) maxVal = 1;

    // Build grid: 7 rows (Mon-Sun) x N weeks
    // Start from (weeks) weeks ago, aligned to Monday
    final startDate = todayDate.subtract(Duration(days: (weeks * 7) - 1 + (todayDate.weekday - 1)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              Column(
                children: [
                  const SizedBox(height: 14), // Month label space
                  ...['L', '', 'Mi', '', 'V', '', 'D'].map((d) => SizedBox(
                    width: 16,
                    height: 14,
                    child: Text(d, style: const TextStyle(fontSize: 8, color: Colors.white38)),
                  )),
                ],
              ),
              // Grid
              ...List.generate(weeks, (weekIdx) {
                final weekStart = startDate.add(Duration(days: weekIdx * 7));
                final showMonth = weekIdx == 0 || weekStart.month != startDate.add(Duration(days: (weekIdx - 1) * 7)).month;
                final monthNames = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

                return Column(
                  children: [
                    // Month label
                    SizedBox(
                      height: 14,
                      width: 14,
                      child: showMonth
                          ? Text(monthNames[weekStart.month], style: const TextStyle(fontSize: 7, color: Colors.white38))
                          : null,
                    ),
                    // 7 days
                    ...List.generate(7, (dayIdx) {
                      final date = weekStart.add(Duration(days: dayIdx));
                      if (date.isAfter(todayDate)) {
                        return const SizedBox(width: 14, height: 14);
                      }
                      final dateKey = DateTime(date.year, date.month, date.day);
                      final value = dailyValues[dateKey] ?? 0;
                      final intensity = value / maxVal;

                      return Padding(
                        padding: const EdgeInsets.all(1),
                        child: Tooltip(
                          message: '${date.day}/${date.month}: $value',
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: value == 0
                                  ? Colors.white.withAlpha(8)
                                  : activeColor.withAlpha((50 + (intensity * 205)).toInt().clamp(50, 255)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Menos', style: TextStyle(fontSize: 8, color: Colors.white38)),
            const SizedBox(width: 4),
            ...List.generate(5, (i) {
              final alpha = i == 0 ? 8 : (50 + (i * 50)).clamp(50, 255);
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i == 0 ? Colors.white.withAlpha(alpha) : activeColor.withAlpha(alpha),
                ),
              );
            }),
            const SizedBox(width: 4),
            const Text('Mas', style: TextStyle(fontSize: 8, color: Colors.white38)),
          ],
        ),
      ],
    );
  }
}
