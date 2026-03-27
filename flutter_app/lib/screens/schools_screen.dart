import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SchoolsScreen extends StatefulWidget {
  const SchoolsScreen({super.key});
  @override
  State<SchoolsScreen> createState() => _SchoolsScreenState();
}

class _SchoolsScreenState extends State<SchoolsScreen> {
  List<School> _schools = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.getSchools();
      if (mounted) setState(() { _schools = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deleteSchool(School s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete School'),
        content: Text('Remove "${s.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteSchool(s.id);
      _fetch();
    } catch (e) {
      _showErr(e.toString());
    }
  }

  void _showErr(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  void _openAddSchool() {
    showDialog(
      context: context,
      builder: (_) => _SchoolDialog(
        onSave: (data) async {
          await ApiService.createSchool(
            schoolCode: data['schoolCode']!,
            name: data['name']!,
            address: data['address'] ?? '',
            phone: data['phone'] ?? '',
            email: data['email'] ?? '',
          );
          _fetch();
        },
      ),
    );
  }

  void _openEditSchool(School s) {
    showDialog(
      context: context,
      builder: (_) => _SchoolDialog(
        school: s,
        onSave: (data) async {
          await ApiService.updateSchool(s.id,
              name: data['name'], address: data['address'],
              phone: data['phone'], email: data['email']);
          _fetch();
        },
      ),
    );
  }

  void _openCreateAdmin(School s) {
    showDialog(context: context, builder: (_) => _CreateAdminDialog(school: s));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _schools.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _schools.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) => _SchoolCard(
                                school: _schools[i],
                                onEdit: () => _openEditSchool(_schools[i]),
                                onDelete: () => _deleteSchool(_schools[i]),
                                onCreateAdmin: () => _openCreateAdmin(_schools[i]),
                                onManageEmployees: () => context.push('/admin',
                                    extra: {'schoolId': _schools[i].id, 'schoolName': _schools[i].name}),
                              ),
                            ),
                          ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSchool,
        backgroundColor: const Color(0xFF854CF4),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Add School'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF4527A0), Color(0xFF854CF4)],
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('School Management', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Manage schools and their admins', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
      IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetch),
    ]),
  );

  Widget _buildError() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 64, color: Colors.red),
    const SizedBox(height: 12),
    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    const SizedBox(height: 16),
    ElevatedButton(onPressed: _fetch, child: const Text('Retry')),
  ]));

  Widget _buildEmpty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.school_outlined, size: 72, color: Colors.black26),
    const SizedBox(height: 16),
    const Text('No schools yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('Tap + to add your first school', style: TextStyle(color: Colors.black54)),
  ]));
}

// ─── School Card ──────────────────────────────────────────────────────────────

class _SchoolCard extends StatelessWidget {
  final School school;
  final VoidCallback onEdit, onDelete, onCreateAdmin, onManageEmployees;
  const _SchoolCard({required this.school, required this.onEdit, required this.onDelete,
      required this.onCreateAdmin, required this.onManageEmployees});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF854CF4).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(school.schoolCode,
                  style: const TextStyle(color: Color(0xFF854CF4), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(school.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'admin') onCreateAdmin();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit, size: 18, color: Color(0xFF854CF4)), SizedBox(width: 8), Text('Edit'),
                ])),
                const PopupMenuItem(value: 'admin', child: Row(children: [
                  Icon(Icons.admin_panel_settings, size: 18, color: Color(0xFF04D3D3)), SizedBox(width: 8), Text('Create Admin Login'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete'),
                ])),
              ],
            ),
          ]),
          if (school.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.black45), const SizedBox(width: 4),
              Flexible(child: Text(school.address, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ]),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF04D3D3).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_rounded, size: 14, color: Color(0xFF04D3D3)), const SizedBox(width: 5),
                Text('${school.employeeCount} staff',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF04D3D3), fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onManageEmployees,
              icon: const Icon(Icons.manage_accounts, size: 16),
              label: const Text('Manage Employees'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF854CF4), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── School Dialog ────────────────────────────────────────────────────────────

class _SchoolDialog extends StatefulWidget {
  final School? school;
  final Future<void> Function(Map<String, String> data) onSave;
  const _SchoolDialog({this.school, required this.onSave});
  @override
  State<_SchoolDialog> createState() => _SchoolDialogState();
}

class _SchoolDialogState extends State<_SchoolDialog> {
  final _fk = GlobalKey<FormState>();
  late final TextEditingController _code, _name, _address, _phone, _email;
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.school?.schoolCode ?? '');
    _name = TextEditingController(text: widget.school?.name ?? '');
    _address = TextEditingController(text: widget.school?.address ?? '');
    _phone = TextEditingController(text: widget.school?.phone ?? '');
    _email = TextEditingController(text: widget.school?.email ?? '');
  }

  @override
  void dispose() {
    _code.dispose(); _name.dispose(); _address.dispose(); _phone.dispose(); _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _saving = true; _err = null; });
    try {
      await widget.onSave({
        'schoolCode': _code.text.trim(), 'name': _name.text.trim(),
        'address': _address.text.trim(), 'phone': _phone.text.trim(), 'email': _email.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.school != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: const BoxDecoration(color: Color(0xFF854CF4),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(children: [
              Icon(isEdit ? Icons.edit : Icons.add_business, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(isEdit ? 'Edit School' : 'Add School',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _saving ? null : () => Navigator.pop(context)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _fk,
                child: Column(children: [
                  if (!isEdit) ...[
                    _field(_code, 'School Code *', Icons.code,
                        validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
                    const SizedBox(height: 12),
                  ],
                  _field(_name, 'School Name *', Icons.school,
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
                  const SizedBox(height: 12),
                  _field(_address, 'Address', Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(_phone, 'Phone', Icons.phone, keyboard: TextInputType.phone)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_email, 'Email', Icons.email, keyboard: TextInputType.emailAddress)),
                  ]),
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    _errBox(_err!),
                  ],
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving…' : 'Save'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF854CF4), foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text, String? Function(String?)? validator}) =>
      TextFormField(
        controller: ctrl, keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
        validator: validator,
      );

  Widget _errBox(String msg) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Icon(Icons.error_outline, color: Colors.red.shade700, size: 16), const SizedBox(width: 8),
      Expanded(child: Text(msg, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
    ]),
  );
}

// ─── Create Admin Dialog ──────────────────────────────────────────────────────

class _CreateAdminDialog extends StatefulWidget {
  final School school;
  const _CreateAdminDialog({required this.school});
  @override
  State<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<_CreateAdminDialog> {
  final _fk = GlobalKey<FormState>();
  final _loginId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false, _obscure = true;
  String? _err;

  @override
  void dispose() { _loginId.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() { _saving = true; _err = null; });
    try {
      await ApiService.createSchoolAdmin(
        schoolId: widget.school.id,
        loginId: _loginId.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('School admin created successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _err = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: const BoxDecoration(color: Color(0xFF04D3D3),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(children: [
              const Icon(Icons.admin_panel_settings, color: Colors.white), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Create School Admin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(widget.school.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              IconButton(icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _saving ? null : () => Navigator.pop(context)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _fk,
                child: Column(children: [
                  const Text('This admin will only manage employees of this school.',
                      style: TextStyle(color: Colors.black54, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _loginId,
                    decoration: const InputDecoration(labelText: 'Login ID *', prefixIcon: Icon(Icons.person, size: 18),
                        border: OutlineInputBorder(), isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email, keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email, size: 18),
                        border: OutlineInputBorder(), isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password, obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password *', prefixIcon: const Icon(Icons.lock, size: 18),
                      border: const OutlineInputBorder(), isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      helperText: 'Min 8 chars, 1 uppercase, 1 number, 1 symbol',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 16), const SizedBox(width: 8),
                        Expanded(child: Text(_err!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.person_add),
                      label: Text(_saving ? 'Creating…' : 'Create Admin'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF04D3D3), foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
