import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  AttendanceStats? _stats;
  List<AttendanceRecord> _recentRecords = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getStats(),
        ApiService.getAttendance(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as AttendanceStats;
          final all = results[1] as List<AttendanceRecord>;
          _recentRecords = all.take(20).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _buildStatGrid(),
                              const SizedBox(height: 24),
                              _buildEnrolmentProgress(),
                              const SizedBox(height: 24),
                              _buildRecentActivity(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4527A0), Color(0xFF854CF4)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Overview & recent activity',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ─── Error ───────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stat Grid ───────────────────────────────────────────────────────────────

  Widget _buildStatGrid() {
    final s = _stats;
    if (s == null) return const SizedBox.shrink();

    final absentToday = (s.totalEmployees - s.presentToday).clamp(0, s.totalEmployees);
    final items = [
      _StatItem(
        icon: Icons.people_rounded,
        label: 'Total Staff',
        value: '${s.totalEmployees}',
        color: const Color(0xFF854CF4),
      ),
      _StatItem(
        icon: Icons.face_rounded,
        label: 'Enrolled',
        value: '${s.enrolledEmployees}',
        color: const Color(0xFF04D3D3),
      ),
      _StatItem(
        icon: Icons.check_circle_rounded,
        label: 'Present Today',
        value: '${s.presentToday}',
        color: const Color(0xFF2E7D32),
      ),
      _StatItem(
        icon: Icons.cancel_rounded,
        label: 'Absent Today',
        value: '$absentToday',
        color: const Color(0xFFE53935),
      ),
      _StatItem(
        icon: Icons.help_outline_rounded,
        label: 'Unrecognized',
        value: '${s.unrecognizedToday}',
        color: const Color(0xFFF57C00),
      ),
      _StatItem(
        icon: Icons.history_rounded,
        label: 'Total Records',
        value: '${s.totalRecords}',
        color: const Color(0xFF1565C0),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.7,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildStatCard(items[i]),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                  Text(
                    item.label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Enrolment Progress ──────────────────────────────────────────────────────

  Widget _buildEnrolmentProgress() {
    final s = _stats;
    if (s == null) return const SizedBox.shrink();
    final pct = s.totalEmployees == 0
        ? 0.0
        : (s.enrolledEmployees / s.totalEmployees).clamp(0.0, 1.0);
    final attendancePct = s.totalEmployees == 0
        ? 0.0
        : (s.presentToday / s.totalEmployees).clamp(0.0, 1.0);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: Color(0xFF854CF4), size: 20),
                SizedBox(width: 8),
                Text(
                  'Enrolment & Attendance Rate',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressRow(
              label: 'Face Enrolment',
              pct: pct,
              color: const Color(0xFF04D3D3),
              detail: '${s.enrolledEmployees} / ${s.totalEmployees}',
            ),
            const SizedBox(height: 14),
            _buildProgressRow(
              label: "Today's Attendance",
              pct: attendancePct,
              color: const Color(0xFF2E7D32),
              detail: '${s.presentToday} / ${s.totalEmployees}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required double pct,
    required Color color,
    required String detail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text(
              '${(pct * 100).toStringAsFixed(0)}%  ($detail)',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ─── Recent Activity ─────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline_rounded, color: Color(0xFF854CF4), size: 20),
                SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recentRecords.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No records yet', style: TextStyle(color: Colors.black38)),
                ),
              )
            else
              ...(_recentRecords.map((r) => _buildRecordTile(r))),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(AttendanceRecord r) {
    final isPresent = r.status == 'present';
    final isUnrecognized = r.status == 'unrecognized';
    final color = isPresent
        ? const Color(0xFF2E7D32)
        : isUnrecognized
            ? const Color(0xFFF57C00)
            : const Color(0xFF6B7280);
    final icon = isPresent
        ? Icons.check_circle_rounded
        : isUnrecognized
            ? Icons.help_rounded
            : Icons.cancel_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.employeeName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('hh:mm a').format(r.timestamp.toLocal()),
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
              Text(
                DateFormat('d MMM').format(r.timestamp.toLocal()),
                style: const TextStyle(fontSize: 10, color: Colors.black38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.icon, required this.label, required this.value, required this.color});
}
