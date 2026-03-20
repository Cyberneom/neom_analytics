import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/app_circular_progress_indicator.dart';

import 'package:sint/sint.dart';

import '../data/firestore/flow_log_firestore.dart';
import '../domain/models/flow_log_entry.dart';
import '../utils/constants/analytic_translation_constants.dart';

/// Dashboard for visualizing user flow durations and screen activity.
///
/// Shows:
/// - Summary cards (total flows, avg duration, success rate)
/// - Flow duration bar chart
/// - Expandable flow cards with step breakdown
/// - Screen visit summary
class FlowMonitorPage extends StatefulWidget {

  const FlowMonitorPage({super.key});

  @override
  State<FlowMonitorPage> createState() => _FlowMonitorPageState();
}

class _FlowMonitorPageState extends State<FlowMonitorPage> {

  final FlowLogFirestore _firestore = FlowLogFirestore();
  List<FlowLogEntry> _flows = [];
  List<ScreenLogEntry> _screenLogs = [];
  bool _isLoading = true;
  String? _expandedFlow;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _firestore.getAllFlows(),
      _firestore.getScreenLogs(days: 7),
    ]);
    _flows = results[0] as List<FlowLogEntry>;
    _screenLogs = results[1] as List<ScreenLogEntry>;
    setState(() => _isLoading = false);
  }

  int get _totalCompletions => _flows.fold(0, (acc, e) => acc + e.totalCompletions);
  int get _totalFailures => _flows.fold(0, (acc, e) => acc + e.totalFailures);
  int get _totalScreenVisits => _screenLogs.fold(0, (acc, e) => acc + e.totalVisits);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SintAppBar(
        title: AnalyticTranslationConstants.flowMonitorTitle.tr,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      backgroundColor: AppFlavour.getBackgroundColor(),
      body: Container(
        decoration: AppTheme.appBoxDecoration,
        child: _isLoading
            ? const AppCircularProgressIndicator()
            : _flows.isEmpty && _screenLogs.isEmpty
                ? Center(
                    child: Text(
                      AnalyticTranslationConstants.noFlowData.tr,
                      style: const TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSummaryCards(),
                        if (_flows.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildFlowDurationChart(),
                          const SizedBox(height: 24),
                          _buildFlowCards(),
                        ],
                        if (_screenLogs.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildScreenSection(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _summaryCard(
          AnalyticTranslationConstants.flowCompletions.tr,
          '$_totalCompletions',
          Icons.check_circle_outline,
          Colors.green,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          AnalyticTranslationConstants.flowFailures.tr,
          '$_totalFailures',
          Icons.error_outline,
          Colors.red,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          AnalyticTranslationConstants.screenVisits.tr,
          '$_totalScreenVisits',
          Icons.visibility_outlined,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColor.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowDurationChart() {
    if (_flows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AnalyticTranslationConstants.avgFlowDuration.tr,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _flows.length * 50.0 + 20,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _flows.map((e) => e.avgDurationMs.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${_flows[group.x].displayName}\n${_flows[group.x].avgDurationFormatted}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _flows.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _flows[idx].displayName,
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        String label;
                        if (value < 1000) {
                          label = '${value.toInt()}ms';
                        } else if (value < 60000) {
                          label = '${(value / 1000).toStringAsFixed(0)}s';
                        } else {
                          label = '${(value / 60000).toStringAsFixed(0)}m';
                        }
                        return Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9));
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _flows.map((e) => e.avgDurationMs.toDouble()).reduce((a, b) => a > b ? a : b) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withAlpha(12),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _flows.asMap().entries.map((entry) {
                  final color = _durationColor(entry.value.avgDurationMs);
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.avgDurationMs.toDouble(),
                        color: color,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                groupsSpace: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AnalyticTranslationConstants.flowDetails.tr,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._flows.map(_buildFlowCard),
      ],
    );
  }

  Widget _buildFlowCard(FlowLogEntry flow) {
    final isExpanded = _expandedFlow == flow.flowName;
    final successRate = flow.successRate;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColor.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() {
              _expandedFlow = isExpanded ? null : flow.flowName;
            }),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _durationColor(flow.avgDurationMs),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flow.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${flow.totalCompletions} ${AnalyticTranslationConstants.completions.tr} · '
                          '${flow.avgDurationFormatted} ${AnalyticTranslationConstants.avgLabel.tr}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Success rate badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _successColor(successRate).withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(successRate * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: _successColor(successRate),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          // Expanded details
          if (isExpanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Steps breakdown
                  if (flow.steps.isNotEmpty) ...[
                    Text(
                      AnalyticTranslationConstants.flowSteps.tr,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...flow.sortedSteps.map((step) => _buildStepRow(step, flow)),
                    const SizedBox(height: 16),
                  ],
                  // Recent flows
                  if (flow.recentFlows.isNotEmpty) ...[
                    Text(
                      AnalyticTranslationConstants.recentFlows.tr,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...flow.recentFlows.take(5).map(_buildRecentFlowRow),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(MapEntry<String, FlowStepEntry> step, FlowLogEntry flow) {
    final stepName = step.key.replaceAll('_', ' ');
    final fraction = flow.avgDurationMs > 0
        ? (step.value.avgDurationMs / flow.avgDurationMs).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              stepName,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  backgroundColor: Colors.white.withAlpha(12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _durationColor(step.value.avgDurationMs),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              step.value.avgDurationFormatted,
              style: TextStyle(
                color: _durationColor(step.value.avgDurationMs),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              '×${step.value.count}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFlowRow(RecentFlowEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            entry.success ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: entry.success ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.userId.isNotEmpty ? entry.userId : 'anonymous',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            entry.durationFormatted,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          if (entry.timestamp != null) ...[
            const SizedBox(width: 8),
            Text(
              _formatTimestamp(entry.timestamp!),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScreenSection() {
    // Aggregate all screen visits across days
    final Map<String, int> aggregated = {};
    for (final log in _screenLogs) {
      for (final entry in log.screens.entries) {
        aggregated[entry.key] = (aggregated[entry.key] ?? 0) + entry.value;
      }
    }
    final sorted = aggregated.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '${AnalyticTranslationConstants.screenVisits.tr} (${_screenLogs.length} ${AnalyticTranslationConstants.daysLabel.tr})',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.take(15).map((entry) {
            final maxCount = sorted.first.value;
            final fraction = maxCount > 0 ? (entry.value / maxCount).clamp(0.0, 1.0) : 0.0;
            final screenName = entry.key.replaceAll('_', ' ');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      screenName,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: Colors.white.withAlpha(12),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${entry.value}',
                      style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _durationColor(int durationMs) {
    if (durationMs >= 30000) return Colors.red;
    if (durationMs >= 10000) return Colors.orange;
    if (durationMs >= 5000) return Colors.amber;
    return Colors.green;
  }

  Color _successColor(double rate) {
    if (rate >= 0.95) return Colors.green;
    if (rate >= 0.8) return Colors.amber;
    if (rate >= 0.5) return Colors.orange;
    return Colors.red;
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
