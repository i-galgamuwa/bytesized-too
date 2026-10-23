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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await _statsService.loadPerformance(widget.user.driverId);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
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
                icon: const Icon(Icons.menu, color: AppColors.cream),
              ),
              const Text(
                'Performance',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (_loading || stats == null)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.cream),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.cream,
                backgroundColor: AppColors.card,
                onRefresh: _load,
                child: ListView(
                  children: [
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly visits: ${stats.weeklyVisits}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 90,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: _visitChartMax(stats.dailyVisits),
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    color: AppColors.gold,
                                    spots: [
                                      for (var i = 0; i < 7; i++)
                                        FlSpot(
                                          i.toDouble(),
                                          stats.dailyVisits[i].toDouble(),
                                        ),
                                    ],
                                    dotData: const FlDotData(show: false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Distance · last 7 days',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  stats.totalDistanceKm.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: AppColors.cream,
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
                                  color: AppColors.cream,
                                  backgroundColor: AppColors.cardHighlight,
                                ),
                                Text(
                                  '${stats.totalDistanceKm.toStringAsFixed(0)} km',
                                  style: const TextStyle(
                                    color: AppColors.cream,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Daily activity',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 120,
                                  child: BarChart(
                                    BarChartData(
                                      minY: 0,
                                      maxY: _barMax(stats.dailyDistanceKm),
                                      gridData: const FlGridData(show: false),
                                      borderData: FlBorderData(show: false),
                                      titlesData: FlTitlesData(
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
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
                                                DateFormat('EEE').format(
                                                  stats.dailyDates[i],
                                                ),
                                                style: const TextStyle(
                                                  color: AppColors.muted,
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
                                                color: AppColors.cream,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _card(
                            child: Column(
                              children: [
                                const Text(
                                  'Hours active',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                                const SizedBox(height: 16),
                                const Icon(
                                  Icons.access_time,
                                  color: AppColors.gold,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  stats.hoursActive.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: AppColors.cream,
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
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly summary',
                            style: TextStyle(color: AppColors.gold),
                          ),
                          const SizedBox(height: 10),
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
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.cream)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}
