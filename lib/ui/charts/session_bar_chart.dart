import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SessionBarChart extends StatelessWidget {

  final Map<int, int> sessions;


  const SessionBarChart({
    this.sessions = const <int, int>{},
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          barGroups: sessions.entries.map((entry) =>
              BarChartGroupData(x: 1, barRods: [
                BarChartRodData(
                    toY: entry.value.toDouble(), width: 14)
              ])).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                return Text(sessions.keys.elementAt(index).toString(),
                    style: const TextStyle(fontSize: 8));
              },
            )),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
        ),
      ),
    );
  }

}
