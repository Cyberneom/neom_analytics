import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';

/// Audience demographics data.
class AudienceDemographics {
  /// Subscription level → count
  final Map<String, int> subscriptionBreakdown;
  /// Hour of day (0-23) → session count
  final Map<int, int> peakHours;
  /// Day of week (1=Mon, 7=Sun) → session count
  final Map<int, int> dayOfWeekActivity;
  /// Total unique users
  final int totalUniqueUsers;
  /// New users this month
  final int newUsersThisMonth;
  /// Returning users (2+ months active)
  final int returningUsers;

  const AudienceDemographics({
    required this.subscriptionBreakdown,
    required this.peakHours,
    required this.dayOfWeekActivity,
    required this.totalUniqueUsers,
    required this.newUsersThisMonth,
    required this.returningUsers,
  });
}

/// Card showing audience demographics for creators.
class AudienceDemographicsCard extends StatelessWidget {

  final AudienceDemographics demographics;
  final String audienceLabel; // "lectores" or "oyentes"

  const AudienceDemographicsCard({
    super.key,
    required this.demographics,
    this.audienceLabel = 'usuarios',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User stats row
        Row(
          children: [
            _buildMiniStat(Icons.people, '${demographics.totalUniqueUsers}', '$audienceLabel totales'),
            const SizedBox(width: 8),
            _buildMiniStat(Icons.person_add, '${demographics.newUsersThisMonth}', 'nuevos este mes'),
            const SizedBox(width: 8),
            _buildMiniStat(Icons.repeat, '${demographics.returningUsers}', 'recurrentes'),
          ],
        ),
        const SizedBox(height: 16),

        // Peak hours mini chart
        const Text('Horas pico', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _buildHourChart(),
        const SizedBox(height: 16),

        // Day of week activity
        const Text('Actividad por dia', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _buildDayOfWeekChart(),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColor.bondiBlue, size: 16),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildHourChart() {
    int maxVal = 0;
    demographics.peakHours.forEach((_, v) { if (v > maxVal) maxVal = v; });
    if (maxVal == 0) maxVal = 1;

    // Find peak hour
    int peakHour = 0;
    int peakCount = 0;
    demographics.peakHours.forEach((h, c) {
      if (c > peakCount) { peakCount = c; peakHour = h; }
    });

    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (hour) {
          final val = demographics.peakHours[hour] ?? 0;
          final ratio = val / maxVal;
          final isPeak = hour == peakHour && val > 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: ratio.clamp(0.05, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isPeak ? const Color(0xFFFF9800) : AppColor.bondiBlue.withAlpha(150),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                  if (hour % 6 == 0)
                    Text('${hour}h', style: const TextStyle(fontSize: 7, color: Colors.white38))
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayOfWeekChart() {
    const days = ['L', 'M', 'Mi', 'J', 'V', 'S', 'D'];
    int maxVal = 0;
    demographics.dayOfWeekActivity.forEach((_, v) { if (v > maxVal) maxVal = v; });
    if (maxVal == 0) maxVal = 1;

    return Row(
      children: List.generate(7, (i) {
        final day = i + 1;
        final val = demographics.dayOfWeekActivity[day] ?? 0;
        final ratio = val / maxVal;

        return Expanded(
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: ratio.clamp(0.1, 1.0),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColor.bondiBlue.withAlpha((100 + ratio * 155).toInt()),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(days[i], style: const TextStyle(fontSize: 9, color: Colors.white38)),
            ],
          ),
        );
      }),
    );
  }
}
