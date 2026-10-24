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
      final pastFuture = _stats.loadShifts(widget.user.driverId);
      final upcomingFuture = _schedule.getUpcomingShifts();
      final past = await pastFuture;
      final upcoming = await upcomingFuture;
      if (!mounted) return;
      setState(() {
        _past = past;
        _upcoming = upcoming;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load shifts: $error';
        _loading = false;
      });
    }
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
                icon: Icon(Icons.menu, color: context.colors.cream),
              ),
              Text(
                'Shifts',
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
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
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
                    Text(
                      'Upcoming shifts',
                      style: TextStyle(
                        color: context.colors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
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
                                color: context.colors.cardHighlight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'SAMPLE',
                                style: TextStyle(
                                  color: context.colors.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              shift.title,
                              style: TextStyle(
                                color: context.colors.cream,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${dateFormat.format(shift.start)}  '
                              '${timeFormat.format(shift.start)} – ${timeFormat.format(shift.end)}',
                              style: TextStyle(color: context.colors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Past shifts',
                      style: TextStyle(
                        color: context.colors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_past.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No shifts recorded yet. Start tracking to create one.',
                          style: TextStyle(color: context.colors.muted),
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
                                  style: TextStyle(
                                    color: context.colors.cream,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Start ${timeFormat.format(shift.startTime)}  ·  '
                                  'End ${shift.endTime == null ? 'In progress' : timeFormat.format(shift.endTime!)}',
                                  style: TextStyle(color: context.colors.muted),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${_duration(shift.duration)}  ·  ${shift.distanceKm.toStringAsFixed(1)} km',
                                  style: TextStyle(color: context.colors.gold),
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
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
