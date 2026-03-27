import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  AuthUser? _user;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  List<AttendanceRecord> _todayRecords = [];
  bool _loadingRecords = false;

  DateTime? _checkinTime;
  DateTime? _checkoutTime;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _init();
  }

  Future<void> _init() async {
    await Future.wait([_loadUser(), _loadLocalState(), _fetchTodayRecords()]);
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getSession();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _loadLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ci = prefs.getString('checkin_$today');
    final co = prefs.getString('checkout_$today');
    if (mounted) {
      setState(() {
        _checkinTime = ci != null ? DateTime.tryParse(ci) : null;
        _checkoutTime = co != null ? DateTime.tryParse(co) : null;
      });
    }
  }

  Future<void> _fetchTodayRecords() async {
    if (!mounted) return;
    setState(() => _loadingRecords = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final records = await ApiService.getAttendance(date: dateStr, schoolId: _user?.schoolId);
      if (mounted) setState(() { _todayRecords = records; _loadingRecords = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _attendanceStatus {
    if (_checkoutTime != null) return 'checked_out';
    if (_checkinTime != null) return 'checked_in';
    return 'not_marked';
  }

  String _getGreeting() {
    final h = _now.hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Future<void> _handleCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    await prefs.setString('checkin_$today', now.toIso8601String());
    if (mounted) setState(() => _checkinTime = now);
    context.push('/scan', extra: {'type': 'checkin', 'schoolId': _user?.schoolId}).then((_) {
      _loadLocalState();
      _fetchTodayRecords();
    });
  }

  Future<void> _handleCheckOut() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    await prefs.setString('checkout_$today', now.toIso8601String());
    if (mounted) setState(() => _checkoutTime = now);
    context.push('/scan', extra: {'type': 'checkout', 'schoolId': _user?.schoolId}).then((_) {
      _loadLocalState();
      _fetchTodayRecords();
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.logout();
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm:ss a').format(_now);
    final dateStr = DateFormat('EEE, d MMM yyyy').format(_now);
    final status = _attendanceStatus;
    final isCheckedIn = status == 'checked_in';
    final isCheckedOut = status == 'checked_out';
    final isNotMarked = status == 'not_marked';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchTodayRecords();
            await _loadLocalState();
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Header ──────────────────────────────────────────────────
              _buildHeader(timeStr, dateStr),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Attendance Status Card ───────────────────────────
                    _buildStatusCard(isCheckedIn, isCheckedOut, isNotMarked),
                    const SizedBox(height: 28),

                    // ── Primary Action Buttons ───────────────────────────
                    _buildActionButtons(isCheckedIn, isCheckedOut),
                    const SizedBox(height: 16),

                    // ── Login / Logout Button ────────────────────────────
                    Center(child: _buildAuthButton()),
                    const SizedBox(height: 28),

                    // ── Info Cards ───────────────────────────────────────
                    _buildInfoRow(),
                    const SizedBox(height: 28),

                    // ── Quick Actions ────────────────────────────────────
                    _buildQuickActions(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(String timeStr, String dateStr) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4527A0), Color(0xFF854CF4)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: logo + branding + icons
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset('assets/launcher_icon.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EdProwise',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'Smart Attendance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5722),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () {},
                tooltip: 'Notifications',
              ),
              if (_user != null)
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: Text(
                    _user!.loginId.isNotEmpty
                        ? _user!.loginId[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 22),

          // Greeting + user name
          Text(
            _getGreeting(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            _user?.loginId ?? 'Guest',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 18),

          // Clock + date row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_filled_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 7),
              Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Attendance Status Card ──────────────────────────────────────────────────

  Widget _buildStatusCard(bool isCheckedIn, bool isCheckedOut, bool isNotMarked) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSub;

    if (isCheckedOut) {
      statusColor = const Color(0xFFE53935);
      statusIcon = Icons.logout_rounded;
      statusTitle = 'Checked Out';
      statusSub = 'at ${DateFormat('hh:mm a').format(_checkoutTime!)}';
    } else if (isCheckedIn) {
      statusColor = const Color(0xFF2E7D32);
      statusIcon = Icons.login_rounded;
      statusTitle = 'Checked In';
      statusSub = 'at ${DateFormat('hh:mm a').format(_checkinTime!)}';
    } else {
      statusColor = const Color(0xFF6B7280);
      statusIcon = Icons.pending_actions_rounded;
      statusTitle = 'Not Marked Yet';
      statusSub = 'Tap the button below to check in';
    }

    return Card(
      elevation: 5,
      shadowColor: statusColor.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.22), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(statusSub,
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isCheckedIn
                        ? 'IN'
                        : isCheckedOut
                            ? 'OUT'
                            : '--',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.8),
            const SizedBox(height: 12),
            // Indicators
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusBadge(
                  icon: Icons.location_on_rounded,
                  label: 'Within Office Range',
                  color: const Color(0xFF2E7D32),
                ),
                _StatusBadge(
                  icon: Icons.gps_fixed_rounded,
                  label: 'GPS Active',
                  color: const Color(0xFF1565C0),
                ),
                if (isCheckedIn || isCheckedOut)
                  _StatusBadge(
                    icon: Icons.face_rounded,
                    label: 'Face Verified',
                    color: const Color(0xFF7B1FA2),
                  ),
                if (_loadingRecords)
                  _StatusBadge(
                    icon: Icons.sync_rounded,
                    label: 'Syncing...',
                    color: const Color(0xFFF57C00),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Primary Action Buttons ──────────────────────────────────────────────────

  Widget _buildActionButtons(bool isCheckedIn, bool isCheckedOut) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleButton(
          label: 'Check In',
          icon: Icons.login_rounded,
          colorLight: const Color(0xFF43A047),
          colorDark: const Color(0xFF1B5E20),
          done: isCheckedIn || isCheckedOut,
          onTap: _handleCheckIn,
        ),
        const SizedBox(width: 28),
        _buildCircleButton(
          label: 'Check Out',
          icon: Icons.logout_rounded,
          colorLight: const Color(0xFFEF5350),
          colorDark: const Color(0xFFB71C1C),
          done: isCheckedOut,
          onTap: _handleCheckOut,
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required String label,
    required IconData icon,
    required Color colorLight,
    required Color colorDark,
    required bool done,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          ScaleTransition(
            scale: done ? AlwaysStoppedAnimation(1.0) : _pulseAnim,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (done ? const Color(0xFF4CAF50) : colorLight)
                        .withValues(alpha: 0.12),
                  ),
                ),
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: done
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [colorLight, colorDark],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: (done ? const Color(0xFF2E7D32) : colorDark)
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        done ? Icons.check_circle_rounded : icon,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        done ? 'Done' : label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: done ? const Color(0xFF2E7D32) : Colors.black45,
              fontSize: 11,
              fontWeight: done ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Login / Logout Button ───────────────────────────────────────────────────

  Widget _buildAuthButton() {
    if (_user == null) {
      return SizedBox(
        width: 220,
        child: ElevatedButton.icon(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Login'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
    return SizedBox(
      width: 220,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, color: Colors.red),
        label: const Text('Logout', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ─── Info Row ────────────────────────────────────────────────────────────────

  Widget _buildInfoRow() {
    final todayPresent = _todayRecords.where((r) => r.status == 'present').length;

    String workingHours = '0h 0m';
    if (_checkinTime != null) {
      final end = _checkoutTime ?? _now;
      final diff = end.difference(_checkinTime!);
      workingHours = '${diff.inHours}h ${diff.inMinutes % 60}m';
    }

    String lastRecord = 'No record yet';
    if (_todayRecords.isNotEmpty) {
      final last = _todayRecords.last;
      lastRecord = DateFormat('hh:mm a').format(last.timestamp.toLocal());
    }

    return Row(
      children: [
        Expanded(
          child: _InfoCard(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFF854CF4),
            label: 'Last Record',
            value: lastRecord,
            sub: _loadingRecords ? 'Loading...' : '$todayPresent scan(s) today',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            icon: Icons.timer_rounded,
            iconColor: const Color(0xFF04D3D3),
            label: 'Working Hours',
            value: workingHours,
            sub: 'Today (auto-calculated)',
          ),
        ),
      ],
    );
  }

  // ─── Quick Actions ───────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionTile(
                icon: Icons.people_rounded,
                label: 'Manage',
                color: const Color(0xFF854CF4),
                onTap: () {
                  if (_user?.isSuperAdmin == true) {
                    context.push('/schools');
                  } else {
                    context.push('/admin');
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.list_alt_rounded,
                label: 'Logs',
                color: const Color(0xFF6C3FC7),
                onTap: () => context.push('/attendance'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionTile(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                color: const Color(0xFF04D3D3),
                onTap: () => context.push('/stats'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(fontSize: 10.5, color: Colors.black45),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
