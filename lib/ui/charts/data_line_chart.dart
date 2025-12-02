import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';

import '../../utils/constants/analytic_constants.dart';

class DataLineChart extends StatelessWidget {

  final Map<int, int> data;
  final String title;
  final double height;
  final String bottomMsg;

  const DataLineChart({super.key, required this.data, this.title = '', this.height = 200, this.bottomMsg = ''});

  @override
  Widget build(BuildContext context) {

    int highestValue = 0;

    if (data.isNotEmpty) {
      highestValue = data.values.reduce((a, b) => a > b ? a : b);
    }
    final spots = data.entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.toDouble());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (title.isNotEmpty)
          Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        AppTheme.heightSpace20,
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              maxY: ((highestValue/AnalyticConstants.chartYAxisRound).ceil() * AnalyticConstants.chartYAxisRound).toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: FlDotData(show: true),
                ),
              ],
              titlesData: FlTitlesData(
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              // gridData: FlGridData(show: true),
              // borderData: FlBorderData(show: true),
            ),
          ),
        ),
        AppTheme.heightSpace10,
        Text(bottomMsg,
          style: TextStyle(fontSize: 10),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }
}
