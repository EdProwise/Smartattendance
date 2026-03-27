import 'dart:convert';
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
    if (mounted) {
      setState(() {
        _user = user;
        _school = school;
        _history = history;
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
      if (mounted) context.go('/');
    }
  }

  void _showChangePassword() {
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(loginId: _user!.loginId),
    );
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

  Widget _buildSchoolCard(School school) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(Icons.school_rounded, 'School Information'),
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
