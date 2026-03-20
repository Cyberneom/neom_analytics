import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/app_circular_progress_indicator.dart';
import 'package:sint/sint.dart';
import 'package:neom_commons/utils/app_utilities.dart';

import '../data/firestore/error_log_firestore.dart';
import '../domain/models/error_log_entry.dart';
import '../utils/constants/analytic_translation_constants.dart';

/// Dashboard that visualizes error logs per module from Firestore.
///
/// Shows:
/// - Horizontal bar chart of errors per module (sorted by count)
/// - Expandable module cards with operation breakdown
/// - Recent error messages for each module
/// - Reset controls for admin users
class ErrorMonitorPage extends StatefulWidget {

  const ErrorMonitorPage({super.key});

  @override
  State<ErrorMonitorPage> createState() => _ErrorMonitorPageState();
}

class _ErrorMonitorPageState extends State<ErrorMonitorPage> {

  final ErrorLogFirestore _firestore = ErrorLogFirestore();
  List<ErrorLogEntry> _entries = [];
  bool _isLoading = true;
  String? _expandedModule;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _entries = await _firestore.getAll();
    setState(() => _isLoading = false);
  }

  int get _totalErrors => _entries.fold(0, (sum, e) => sum + e.totalErrors);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SintAppBar(
        title: AnalyticTranslationConstants.errorMonitor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AnalyticTranslationConstants.refresh,
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'reset') {
                final confirmed = await _showResetConfirmation();
                if (confirmed == true) {
                  await _firestore.resetAll();
                  AppUtilities.showSnackBar(
                    title: AnalyticTranslationConstants.errorMonitor,
                    message: AnalyticTranslationConstants.countersReset,
                  );
                  _loadData();
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red.shade300, size: 20),
                    const SizedBox(width: 8),
                    Text(AnalyticTranslationConstants.resetCounters),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: AppFlavour.getBackgroundColor(),
      body: Container(
        decoration: AppTheme.appBoxDecoration,
        child: _isLoading
            ? const Center(child: AppCircularProgressIndicator())
            : _entries.isEmpty
                ? _buildEmptyState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            AnalyticTranslationConstants.noErrorsRecorded,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryRow(),
                const SizedBox(height: 24),
                _buildBarChart(),
                const SizedBox(height: 24),
                Text(
                  AnalyticTranslationConstants.moduleBreakdown,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ..._entries.map(_buildModuleCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final moduleCount = _entries.length;
    final topModule = _entries.isNotEmpty ? _entries.first : null;

    return Row(
      children: [
        _summaryCard(
          AnalyticTranslationConstants.totalErrors,
          '$_totalErrors',
          Colors.red.shade700,
          Icons.error_outline,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          AnalyticTranslationConstants.modulesAffected,
          '$moduleCount',
          Colors.orange.shade700,
          Icons.widgets_outlined,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          AnalyticTranslationConstants.topModule,
          topModule?.displayName ?? '-',
          Colors.amber.shade700,
          Icons.trending_up,
          subtitle: topModule != null ? '${topModule.totalErrors} errors' : null,
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color color, IconData icon, {String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                    style: TextStyle(color: color.withAlpha(200), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(130), fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_entries.isEmpty) return const SizedBox.shrink();

    // Show top 15 modules
    final top = _entries.take(15).toList();
    final maxVal = top.first.totalErrors.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColor.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AnalyticTranslationConstants.errorsByModule,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: (top.length * 40.0).clamp(120, 600),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipHorizontalAlignment: FLHorizontalAlignment.right,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      final entry = top[group.x];
                      return BarTooltipItem(
                        '${entry.displayName}\n${entry.totalErrors} errors',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 100,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= top.length) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            top[idx].displayName,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: false,
                  verticalInterval: maxVal > 0 ? (maxVal / 4).ceilToDouble().clamp(1, double.infinity) : 1,
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.white.withAlpha(15),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: top.asMap().entries.map((e) {
                  final idx = e.key;
                  final entry = e.value;
                  final color = _barColor(idx, top.length);
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: entry.totalErrors.toDouble(),
                        color: color,
                        width: 18,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
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

  Color _barColor(int index, int total) {
    if (total <= 1) return Colors.red;
    // Gradient from red (highest) to amber (lowest)
    final t = index / (total - 1);
    return Color.lerp(Colors.red.shade400, Colors.amber.shade300, t)!;
  }

  Widget _buildModuleCard(ErrorLogEntry entry) {
    final isExpanded = _expandedModule == entry.module;
    final sortedOps = entry.sortedOperations;
    final topOp = sortedOps.isNotEmpty ? sortedOps.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColor.borderSubtle),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _expandedModule = isExpanded ? null : entry.module;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _priorityBadge(entry.totalErrors),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        if (topOp != null)
                          Text(
                            '${AnalyticTranslationConstants.topOperation}: ${topOp.key} (${topOp.value})',
                            style: TextStyle(color: Colors.white.withAlpha(130), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${entry.totalErrors}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          // Expanded details
          if (isExpanded) ...[
            Divider(height: 1, color: AppColor.borderSubtle),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Operations breakdown
                  Text(
                    AnalyticTranslationConstants.operations,
                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...sortedOps.map((op) => _buildOperationRow(op, entry.totalErrors)),
                  // Recent errors
                  if (entry.recentErrors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      AnalyticTranslationConstants.recentErrors,
                      style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...entry.recentErrors.take(5).map(_buildRecentErrorRow),
                  ],
                  // Last error time
                  if (entry.lastErrorAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${AnalyticTranslationConstants.lastError}: ${_formatAge(entry.lastErrorAt!)}',
                      style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationRow(MapEntry<String, int> op, int moduleTotal) {
    final percentage = moduleTotal > 0 ? op.value / moduleTotal : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              op.key,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.white.withAlpha(15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage > 0.5 ? Colors.red.shade400 : Colors.amber.shade400,
                ),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '${op.value}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentErrorRow(RecentError error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red.shade300),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error.operation,
                  style: TextStyle(color: Colors.amber.shade300, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  error.message,
                  style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (error.timestamp != null)
            Text(
              _formatAge(error.timestamp!),
              style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 10),
            ),
        ],
      ),
    );
  }

  Widget _priorityBadge(int errorCount) {
    Color color;
    String label;
    if (errorCount >= 100) {
      color = Colors.red;
      label = AnalyticTranslationConstants.critical;
    } else if (errorCount >= 30) {
      color = Colors.orange;
      label = AnalyticTranslationConstants.high;
    } else if (errorCount >= 10) {
      color = Colors.amber;
      label = AnalyticTranslationConstants.medium;
    } else {
      color = Colors.green;
      label = AnalyticTranslationConstants.low;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatAge(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return 'hace ${diff.inDays}d';
    if (diff.inHours > 0) return 'hace ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'hace ${diff.inMinutes}m';
    return 'ahora';
  }

  Future<bool?> _showResetConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(AnalyticTranslationConstants.resetCounters,
          style: const TextStyle(color: Colors.white)),
        content: Text(AnalyticTranslationConstants.resetConfirmation,
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AnalyticTranslationConstants.cancel, style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AnalyticTranslationConstants.reset, style: TextStyle(color: Colors.red.shade300)),
          ),
        ],
      ),
    );
  }
}
