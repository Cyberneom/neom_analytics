
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pie_chart/pie_chart.dart' as pie_chart;


class CustomPieChart extends StatelessWidget {
  CustomPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pie chart'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              pie_chart.PieChart(
                dataMap: data,
                chartType: pie_chart.ChartType.disc,
                degreeOptions: const pie_chart.DegreeOptions(totalDegrees: 360, initialAngle: 0),
                baseChartColor: Colors.transparent,
                animationDuration: 1.seconds,
                // colorList: const [Colors.blue, Colors.red, Colors.green, Colors.yellow, Colors.orange],
              ),
            ],
          ),
        ),
      ),
    );
  }

  final Map<String, double> data = {
    'Freemium': 15,
    'EMXI Lecturas': 5,
    'Posiciónate': 3,
    'Conecta': 3,
    'Artista': 4,
    'Profesional': 5,
    'Premium': 4,
    'Publícate': 4
  };
}
