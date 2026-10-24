import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    super.key,
    required this.user,
    required this.onOpenDrawer,
  });

  final AuthUser user;
  final VoidCallback onOpenDrawer;

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final _statsService = StatsService();
  PerformanceStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _statsService.loadPerformance(widget.user.driverId);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load performance: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onOpenDrawer,
                icon: Icon(Icons.menu, color: context.colors.cream),
              ),
              Text(
                'Performance',
                style: TextStyle(
                  color: context.colors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (_loading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(color: context.colors.cream),
              ),
            )
          else if (_error != null || stats == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Performance data is unavailable.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.muted),
                    ),
                    SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _load,
                      icon: Icon(Icons.refresh, color: context.colors.gold),
                      label: Text(
                        'Retry',
                        style: TextStyle(color: context.colors.gold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: context.colors.cream,
                backgroundColor: context.colors.card,
                onRefresh: _load,
                child: ListView(
                  children: [
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly visits: ${stats.weeklyVisits}',
                            style: TextStyle(color: context.colors.muted),
                          ),
                          SizedBox(height: 8),
                          SizedBox(
                            height: 90,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: _visitChartMax(stats.dailyVisits),
                                gridData: FlGridData(show: false),
                                titlesData: FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    color: context.colors.gold,
                                    spots: [
                                      for (var i = 0; i < 7; i++)
                                        FlSpot(
                                          i.toDouble(),
                                          stats.dailyVisits[i].toDouble(),
                                        ),
                                    ],
                                    dotData: FlDotData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    _card(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Distance · last 7 days',
                                  style: TextStyle(color: context.colors.muted),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  stats.totalDistanceKm.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: context.colors.cream,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: (stats.totalDistanceKm / 200).clamp(
                                    0,
                                    1,
                                  ),
                                  strokeWidth: 10,
                                  color: context.colors.cream,
                                  backgroundColor: context.colors.cardHighlight,
                                ),
                                Text(
                                  '${stats.totalDistanceKm.toStringAsFixed(0)} km',
                                  style: TextStyle(
                                    color: context.colors.cream,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily activity',
                                  style: TextStyle(color: context.colors.muted),
                                ),
                                SizedBox(height: 12),
                                SizedBox(
                                  height: 120,
                                  child: BarChart(
                                    BarChartData(
                                      minY: 0,
                                      maxY: _barMax(stats.dailyDistanceKm),
                                      gridData: FlGridData(show: false),
                                      borderData: FlBorderData(show: false),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, _) {
                                              final i = value.toInt();
                                              if (i < 0 || i > 6) {
                                                return const SizedBox.shrink();
                                              }
                                              return Text(
                                                DateFormat(
                                                  'EEE',
                                                ).format(stats.dailyDates[i]),
                                                style: TextStyle(
                                                  color: context.colors.muted,
                                                  fontSize: 10,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      barGroups: [
                                        for (var i = 0; i < 7; i++)
                                          BarChartGroupData(
                                            x: i,
                                            barRods: [
                                              BarChartRodData(
                                                toY: stats.dailyDistanceKm[i],
                                                color: context.colors.cream,
                                                width: 8,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _card(
                            child: Column(
                              children: [
                                Text(
                                  'Hours active',
                                  style: TextStyle(color: context.colors.muted),
                                ),
                                SizedBox(height: 16),
                                Icon(
                                  Icons.access_time,
                                  color: context.colors.gold,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  stats.hoursActive.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: context.colors.cream,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly summary',
                            style: TextStyle(color: context.colors.gold),
                          ),
                          SizedBox(height: 10),
                          _summaryRow('Shifts', '${stats.weeklyShifts}'),
                          _summaryRow('Visits', '${stats.weeklyVisits}'),
                          _summaryRow(
                            'Distance · last 7 days',
                            '${stats.weeklyDistanceKm.toStringAsFixed(1)} km',
                          ),
                          _summaryRow(
                            'Hours active',
                            stats.weeklyHoursActive.toStringAsFixed(1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _barMax(List<double> values) {
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    return max <= 0 ? 1 : max * 1.2;
  }

  double _visitChartMax(List<int> values) {
    final maximum = values.fold<int>(0, (a, b) => a > b ? a : b);
    return maximum < 1 ? 1 : maximum * 1.2;
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: context.colors.muted)),
          Spacer(),
          Text(value, style: TextStyle(color: context.colors.cream)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}
