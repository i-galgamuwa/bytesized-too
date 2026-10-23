import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/shift_schedule_service.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import 'shift_detail_screen.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({
    super.key,
    required this.user,
    required this.onOpenDrawer,
  });

  final AuthUser user;
  final VoidCallback onOpenDrawer;

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final _stats = StatsService();
  final _schedule = ShiftScheduleService();
  List<ShiftSummary> _past = [];
  List<ScheduledShift> _upcoming = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final past = await _stats.loadShifts(widget.user.driverId);
    final upcoming = await _schedule.getUpcomingShifts();
    if (!mounted) return;
    setState(() {
      _past = past;
      _upcoming = upcoming;
      _loading = false;
    });
  }

  String _duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE d MMM');
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onOpenDrawer,
                icon: const Icon(Icons.menu, color: AppColors.cream),
              ),
              const Text(
                'Shifts',
                style: TextStyle(
                  color: AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (_loading)
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
                    const Text(
                      'Upcoming shifts',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._upcoming.map(
                      (shift) => _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cardHighlight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SAMPLE',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              shift.title,
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dateFormat.format(shift.start)}  '
                              '${timeFormat.format(shift.start)} – ${timeFormat.format(shift.end)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Past shifts',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_past.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No shifts recorded yet. Start tracking to create one.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    else
                      ..._past.map((shift) {
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ShiftDetailScreen(shift: shift),
                              ),
                            );
                          },
                          child: _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormat.format(shift.startTime),
                                  style: const TextStyle(
                                    color: AppColors.cream,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Start ${timeFormat.format(shift.startTime)}  ·  '
                                  'End ${shift.endTime == null ? 'In progress' : timeFormat.format(shift.endTime!)}',
                                  style: const TextStyle(color: AppColors.muted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_duration(shift.duration)}  ·  ${shift.distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(color: AppColors.gold),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
