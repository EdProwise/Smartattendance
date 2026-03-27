import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthUser? _user;
  School? _school;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.getSession();
    School? school;
    if (user?.schoolId != null) {
      try {
        school = await ApiService.getSchool(user!.schoolId!);
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('attendance_history') ?? '[]';
    final history = List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final hasPin = user != null ? await AuthService.hasPin(user.loginId) : false;
    if (mounted) {
      setState(() {
        _user = user;
        _school = school;
        _history = history;
        _hasPin = hasPin;
        _loading = false;
      });
    }
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
      if (mounted) context.pop();
    }
  }

  void _showChangePassword() {
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(loginId: _user!.loginId),
    );
  }

  Future<void> _showSetOrChangePin() async {
    final loginId = _user!.loginId;
    await showDialog<void>(
      context: context,
      builder: (_) => _ChangePinDialog(loginId: loginId, hasPin: _hasPin),
    );
    // Refresh hasPin state
    final updated = await AuthService.hasPin(loginId);
    if (mounted) setState(() => _hasPin = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = _user!;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // Role + account info
                    _buildAccountCard(user),
                    const SizedBox(height: 14),

                    // School info (school_admin)
                    if (user.isSchoolAdmin && _school != null) ...[
                      _buildSchoolCard(_school!),
                      const SizedBox(height: 14),
                    ],

                    // Super admin badge
                    if (user.isSuperAdmin) ...[
                      _buildSuperAdminCard(),
                      const SizedBox(height: 14),
                    ],

                    // Quick Actions
                    _buildQuickActionsCard(user),
                    const SizedBox(height: 14),

                    // Attendance history
                    _buildHistoryCard(),
                    const SizedBox(height: 14),

                    // Actions
                    _buildActionsCard(user),
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

  Widget _buildHeader(BuildContext context, AuthUser user) {
    final roleLabel = user.isSuperAdmin
        ? 'Super Admin'
        : user.isSchoolAdmin
            ? 'School Admin'
            : 'User';
    final roleColor = user.isSuperAdmin
        ? const Color(0xFF1565C0)
        : user.isSchoolAdmin
            ? const Color(0xFF2E7D32)
            : const Color(0xFF6B7280);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4527A0), Color(0xFF854CF4)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Text(
                  'My Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              user.loginId.isNotEmpty ? user.loginId[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user.loginId,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roleLabel,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Account Card ────────────────────────────────────────────────────────────

  Widget _buildAccountCard(AuthUser user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(Icons.person_outline_rounded, 'Account Details'),
            const SizedBox(height: 12),
            _infoRow(Icons.badge_outlined, 'Login ID', user.loginId),
            const Divider(height: 20),
            _infoRow(Icons.email_outlined, 'Email', user.email),
            if (user.schoolId != null) ...[
              const Divider(height: 20),
              _infoRow(Icons.link_rounded, 'School ID', user.schoolId!),
            ],
          ],
        ),
      ),
    );
  }

  // ─── School Card ─────────────────────────────────────────────────────────────

  Future<void> _showEditSchool(School school) async {
    final updated = await showDialog<School>(
      context: context,
      builder: (_) => _EditSchoolDialog(school: school),
    );
    if (updated != null && mounted) {
      setState(() => _school = updated);
    }
  }

  Widget _buildSchoolCard(School school) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _cardTitle(Icons.school_rounded, 'School Information')),
                InkWell(
                  onTap: () => _showEditSchool(school),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF854CF4).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF854CF4)),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 12, color: Color(0xFF854CF4), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.school_outlined, 'School Name', school.name),
            const Divider(height: 20),
            _infoRow(Icons.tag_rounded, 'School Code', school.schoolCode),
            if (school.email.isNotEmpty) ...[
              const Divider(height: 20),
              _infoRow(Icons.email_outlined, 'School Email', school.email),
            ],
            if (school.phone.isNotEmpty) ...[
              const Divider(height: 20),
              _infoRow(Icons.phone_outlined, 'Phone', school.phone),
            ],
            if (school.address.isNotEmpty) ...[
              const Divider(height: 20),
              _infoRow(Icons.location_on_outlined, 'Address', school.address),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Super Admin Card ────────────────────────────────────────────────────────

  Widget _buildSuperAdminCard() {
    return Card(
      color: const Color(0xFF1565C0).withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF1565C0), size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Super Administrator',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0))),
                  SizedBox(height: 3),
                  Text('Full access to all schools, employees and system settings.',
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick Actions ───────────────────────────────────────────────────────────

  Widget _buildQuickActionsCard(AuthUser user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(Icons.grid_view_rounded, 'Quick Actions'),
            const SizedBox(height: 14),
            Row(
              children: [
                if (user.canManage) ...[
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.people_rounded,
                      label: 'Manage',
                      color: const Color(0xFF854CF4),
                      onTap: () {
                        Navigator.pop(context);
                        Future.microtask(() {
                          if (user.isSuperAdmin) {
                            GoRouter.of(context).push('/schools');
                          } else {
                            GoRouter.of(context).push('/admin');
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.list_alt_rounded,
                    label: 'Logs',
                    color: const Color(0xFF6C3FC7),
                    onTap: () {
                      Navigator.pop(context);
                      Future.microtask(() => GoRouter.of(context).push('/attendance'));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.bar_chart_rounded,
                    label: 'Stats',
                    color: const Color(0xFF04D3D3),
                    onTap: () {
                      Navigator.pop(context);
                      Future.microtask(() => GoRouter.of(context).push('/stats'));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Attendance History ──────────────────────────────────────────────────────

  Widget _buildHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(Icons.history_rounded, 'Attendance History'),
            const SizedBox(height: 12),
            if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No attendance recorded yet.',
                      style: TextStyle(color: Colors.black38)),
                ),
              )
            else
              ...(_history.take(20).map((entry) => _historyTile(entry))),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> entry) {
    final type = entry['type'] as String? ?? 'checkin';
    final ts = DateTime.tryParse(entry['timestamp'] as String? ?? '') ?? DateTime.now();
    final isIn = type == 'checkin';
    final color = isIn ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
    final icon = isIn ? Icons.login_rounded : Icons.logout_rounded;
    final label = isIn ? 'Check In' : 'Check Out';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
                Text(
                  DateFormat('EEE, d MMM yyyy').format(ts.toLocal()),
                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('hh:mm a').format(ts.toLocal()),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }

  // ─── Actions Card ────────────────────────────────────────────────────────────

  Widget _buildActionsCard(AuthUser user) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF854CF4)),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            onTap: _showChangePassword,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: Icon(
              _hasPin ? Icons.pin_rounded : Icons.pin_outlined,
              color: const Color(0xFF854CF4),
            ),
            title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
            subtitle: Text(
              _hasPin ? 'Update your profile access PIN' : 'Protect your profile with a 6-digit PIN',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: _hasPin
                ? const Icon(Icons.chevron_right_rounded, color: Colors.black38)
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Not set',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600)),
                  ),
            onTap: _showSetOrChangePin,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _cardTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF854CF4)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF854CF4))),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black38),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
      ],
    );
  }
}

// ─── Change Password Dialog ───────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final String loginId;
  const _ChangePasswordDialog({required this.loginId});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await AuthService.changePassword(
        loginId: widget.loginId,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ));
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      setState(() { _error = 'Could not connect to server'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF854CF4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Change Password',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                        ]),
                      ),
                    _passField(_currentCtrl, 'Current Password', _obscureCurrent,
                        () => setState(() => _obscureCurrent = !_obscureCurrent),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                    const SizedBox(height: 12),
                    _passField(_newCtrl, 'New Password', _obscureNew,
                        () => setState(() => _obscureNew = !_obscureNew),
                        validator: (v) => AuthService.validatePassword(v ?? '')),
                    const SizedBox(height: 12),
                    _passField(_confirmCtrl, 'Confirm New Password', _obscureConfirm,
                        () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != _newCtrl.text) return 'Passwords do not match';
                          return null;
                        }),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save'),
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
    );
  }

  Widget _passField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
      ),
      validator: validator,
    );
  }
}

// ─── Quick Action Tile ────────────────────────────────────────────────────────

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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
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

// ─── Change / Set PIN Dialog ──────────────────────────────────────────────────

class _ChangePinDialog extends StatefulWidget {
  final String loginId;
  final bool hasPin;
  const _ChangePinDialog({required this.loginId, required this.hasPin});

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog>
    with SingleTickerProviderStateMixin {
  // Steps: 0 = verify current (only if hasPin), 1 = enter new, 2 = confirm new
  late int _step;
  String _current = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _error;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _step = widget.hasPin ? 0 : 1;
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  String get _activePin {
    if (_step == 0) return _current;
    if (_step == 1) return _newPin;
    return _confirmPin;
  }

  void _addDigit(String digit) {
    if (_activePin.length >= 6) return;
    setState(() {
      _error = null;
      if (_step == 0) _current += digit;
      else if (_step == 1) _newPin += digit;
      else _confirmPin += digit;
    });
    if (_activePin.length == 6) _handleComplete();
  }

  void _removeDigit() {
    setState(() {
      if (_step == 0 && _current.isNotEmpty) {
        _current = _current.substring(0, _current.length - 1);
      } else if (_step == 1 && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      } else if (_step == 2 && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  Future<void> _handleComplete() async {
    if (_step == 0) {
      final valid = await AuthService.verifyPin(widget.loginId, _current);
      if (valid) {
        setState(() { _step = 1; _current = ''; });
      } else {
        await _shakeCtrl.forward(from: 0);
        setState(() { _error = 'Incorrect current PIN.'; _current = ''; });
      }
    } else if (_step == 1) {
      setState(() => _step = 2);
    } else {
      if (_confirmPin == _newPin) {
        await AuthService.savePin(widget.loginId, _newPin);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.hasPin ? 'PIN updated successfully' : 'PIN set successfully'),
            backgroundColor: Colors.green,
          ));
        }
      } else {
        await _shakeCtrl.forward(from: 0);
        setState(() {
          _error = 'PINs do not match. Try again.';
          _confirmPin = '';
          _newPin = '';
          _step = 1;
        });
      }
    }
  }

  String get _title {
    if (_step == 0) return 'Verify Current PIN';
    if (_step == 1) return widget.hasPin ? 'Enter New PIN' : 'Set Profile PIN';
    return 'Confirm New PIN';
  }

  String get _subtitle {
    if (_step == 0) return 'Enter your current 6-digit PIN';
    if (_step == 1) return 'Enter a new 6-digit PIN';
    return 'Re-enter your new PIN to confirm';
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.hasPin ? 3 : 2;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF854CF4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pin_rounded, size: 30, color: Color(0xFF854CF4)),
            ),
            const SizedBox(height: 14),
            Text(_title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),

            // Step indicators
            if (totalSteps > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps * 2 - 1, (i) {
                  if (i.isOdd) {
                    final stepIndex = i ~/ 2;
                    final passed = (widget.hasPin ? _step : _step + 1) > stepIndex + 1;
                    return Container(
                      width: 24,
                      height: 2,
                      color: passed ? const Color(0xFF854CF4) : Colors.grey.shade300,
                    );
                  }
                  final stepIndex = i ~/ 2;
                  final currentStep = widget.hasPin ? _step : _step + 1;
                  final isActive = currentStep == stepIndex;
                  final isDone = currentStep > stepIndex;
                  return _StepDot(active: isActive, done: isDone, label: '${stepIndex + 1}');
                }),
              ),
              const SizedBox(height: 20),
            ],

            // Dots with shake
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (ctx, child) {
                final offset = _shakeCtrl.isAnimating
                    ? 8 * math.sin(_shakeAnim.value * math.pi * 6)
                    : 0.0;
                return Transform.translate(offset: Offset(offset, 0), child: child!);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _activePin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? const Color(0xFF854CF4) : Colors.transparent,
                      border: Border.all(
                        color: filled ? const Color(0xFF854CF4) : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500)),
            ],

            const SizedBox(height: 22),

            ...List.generate(3, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (col) {
                    final digit = '${row * 3 + col + 1}';
                    return _PinKeyP(label: digit, onTap: () => _addDigit(digit));
                  }),
                ),
              );
            }),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 72),
                _PinKeyP(label: '0', onTap: () => _addDigit('0')),
                _PinKeyP(icon: Icons.backspace_outlined, onTap: _removeDigit),
              ],
            ),

            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  final String label;
  const _StepDot({required this.active, required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = (active || done) ? const Color(0xFF854CF4) : Colors.grey.shade300;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _PinKeyP extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PinKeyP({this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: label != null
            ? Text(label!,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))
            : Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }
}

// ─── Edit School Dialog ───────────────────────────────────────────────────────

class _EditSchoolDialog extends StatefulWidget {
  final School school;
  const _EditSchoolDialog({required this.school});

  @override
  State<_EditSchoolDialog> createState() => _EditSchoolDialogState();
}

class _EditSchoolDialogState extends State<_EditSchoolDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.school.name);
    _emailCtrl = TextEditingController(text: widget.school.email);
    _phoneCtrl = TextEditingController(text: widget.school.phone);
    _addressCtrl = TextEditingController(text: widget.school.address);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await ApiService.updateSchool(
        widget.school.id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      setState(() { _error = 'Could not connect to server'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF854CF4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Edit School Info',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_error != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                        ]),
                      ),
                    ],
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'School Name *',
                        prefixIcon: Icon(Icons.school_outlined),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'School name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'School Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'e.g. +91 98765 43210',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'Street, City, State',
                        alignLabelWithHint: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 18),
                          label: const Text('Save'),
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
    );
  }
}
