import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/camera_service.dart';
import '../services/excel_helper.dart';
import '../services/file_io_service.dart';
import '../widgets/platform_camera_view.dart';


class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Employee> _employees = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  String? _schoolId;
  String? _schoolName;
  AuthUser? _currentUser;

  @override
  void initState() {
    super.initState();
    CameraService.enroll.init();
    _initUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final incoming = extra?['schoolId'] as String?;
    if (incoming != null && incoming != _schoolId) {
      _schoolId = incoming;
      _schoolName = extra?['schoolName'] as String?;
      _fetchEmployees();
    }
  }

  Future<void> _initUser() async {
    _currentUser = await AuthService.getSession();
    if (_currentUser?.isSchoolAdmin == true && _schoolId == null) {
      _schoolId = _currentUser!.schoolId;
    }
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.getEmployees(schoolId: _schoolId);
      if (mounted) setState(() { _employees = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deleteEmployee(Employee emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Remove ${emp.name} (${emp.employeeId}) from the system?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteEmployee(emp.id);
      _fetchEmployees();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _enrollFace(Employee emp) async {
    final base64Image = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EnrollCameraDialog(employeeName: emp.name),
    );
    if (base64Image == null || base64Image.isEmpty) return;
    try {
      await ApiService.enrollFace(employeeId: emp.id, photoBase64: base64Image);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${emp.name} enrolled successfully!'),
          backgroundColor: Colors.green,
        ));
        _fetchEmployees();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddEmployeeDialog(
        onAdd: (data) async {
          await ApiService.createEmployee(
            schoolId: _schoolId,
            employeeId: data['employeeId']!,
            name: data['name']!,
            designation: data['designation']!,
            grade: data['grade']!,
            category: data['category']!,
            gender: data['gender']!,
            mobile: data['mobile']!,
          );
          _fetchEmployees();
        },
      ),
    );
  }

  // ─── Excel Export ────────────────────────────────────────────────────────────

  Future<void> _exportToExcel() async {
    final bytes = ExcelHelper.exportEmployees(_filteredEmployees);
    final filename =
        'employees_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx';
    final savedPath = await FileIoService.instance.saveExcelFile(bytes, filename);
    if (mounted && savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exported: $savedPath'),
        backgroundColor: Colors.green,
      ));
    }
  }

  // ─── Excel Import ────────────────────────────────────────────────────────────

  Future<void> _importFromExcel() async {
    final picked = await FileIoService.instance.pickExcelFile();
    if (picked == null) return;

    List<Map<String, dynamic>> employees;
    try {
      employees = ExcelHelper.parseEmployees(picked.bytes);
    } catch (e) {
      _showError('Invalid Excel file: $e');
      return;
    }

    if (employees.isEmpty) { _showError('No valid rows found in Excel'); return; }

    try {
      final result = await ApiService.bulkImportEmployees(employees, schoolId: _schoolId);
      final imported = result['imported'] as int;
      final total    = result['total']    as int;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imported $imported / $total employees'),
          backgroundColor: imported == total ? Colors.green : Colors.orange,
        ));
        _fetchEmployees();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  List<Employee> get _filteredEmployees {
    if (_search.isEmpty) return _employees;
    final q = _search.toLowerCase();
    return _employees.where((e) =>
      e.name.toLowerCase().contains(q) ||
      e.employeeId.toLowerCase().contains(q) ||
      e.designation.toLowerCase().contains(q) ||
      e.mobile.toLowerCase().contains(q),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEmployees;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: Text(_schoolName != null ? _schoolName! : 'Employee Management'),
        actions: [
          if (_currentUser?.isSuperAdmin == true && _schoolId == null)
            IconButton(
              icon: const Icon(Icons.school_rounded),
              tooltip: 'Manage Schools',
              onPressed: () => context.push('/schools'),
            ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from Excel',
            onPressed: _importFromExcel,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _employees.isEmpty ? null : _exportToExcel,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchEmployees),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: const Color(0xFF854CF4),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, ID, designation, mobile…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('${filtered.length} employee${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _fetchEmployees, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? _EmptyState(onAdd: _openAddDialog, isSearch: _search.isNotEmpty)
                        : RefreshIndicator(
                            onRefresh: _fetchEmployees,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _EmployeeTile(
                                employee: filtered[i],
                                onDelete: () => _deleteEmployee(filtered[i]),
                                onEnroll: () => _enrollFace(filtered[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Employee Dialog ───────────────────────────────────────────────────────

class _AddEmployeeDialog extends StatefulWidget {
  final Future<void> Function(Map<String, String> data) onAdd;
  const _AddEmployeeDialog({required this.onAdd});

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _empIdCtrl       = TextEditingController();
  final _nameCtrl        = TextEditingController();
  final _mobileCtrl      = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _gradeCtrl       = TextEditingController();
  final _categoryCtrl    = TextEditingController();
  final _genderCtrl      = TextEditingController();
  bool _saving = false;
  String? _errorMsg;

  @override
  void dispose() {
    _empIdCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _designationCtrl.dispose();
    _gradeCtrl.dispose();
    _categoryCtrl.dispose();
    _genderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _errorMsg = null; });
    try {
      await widget.onAdd({
        'employeeId':  _empIdCtrl.text.trim(),
        'name':        _nameCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'grade':       _gradeCtrl.text.trim(),
        'category':    _categoryCtrl.text.trim(),
        'gender':      _genderCtrl.text.trim(),
        'mobile':      _mobileCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('409') || msg.toLowerCase().contains('already exists') || msg.toLowerCase().contains('duplicate')) {
          msg = 'Employee ID "${_empIdCtrl.text.trim()}" already exists. Please use a different ID.';
        }
        setState(() { _saving = false; _errorMsg = msg; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                  const Icon(Icons.person_add, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Add Employee',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Basic Information'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _field(_empIdCtrl, 'Employee ID *', Icons.badge,
                            validator: _required)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_nameCtrl, 'Full Name *', Icons.person,
                            validator: _required)),
                      ]),
                      const SizedBox(height: 12),
                      _field(_mobileCtrl, 'Mobile Number', Icons.phone,
                          keyboard: TextInputType.phone),
                      const SizedBox(height: 20),
                      _sectionLabel('Job Details'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _field(_designationCtrl, 'Designation', Icons.work)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_gradeCtrl, 'Grade', Icons.grade)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _field(_categoryCtrl, 'Category', Icons.category)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_genderCtrl, 'Gender', Icons.person_outline)),
                      ]),
                      const SizedBox(height: 24),
                      if (_errorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMsg!,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                          ]),
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF854CF4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _saving
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving…' : 'Save Employee'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: Color(0xFF854CF4), letterSpacing: 0.5));

  String? _required(String? v) => (v == null || v.isEmpty) ? 'Required' : null;

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: validator ?? (v) => null,
    );
  }
}

// ─── Enroll Dialog ────────────────────────────────────────────────────────────

enum _EnrollStep { choice, cameraStarting, cameraLive, preview }

class _EnrollCameraDialog extends StatefulWidget {
  final String employeeName;
  const _EnrollCameraDialog({required this.employeeName});

  @override
  State<_EnrollCameraDialog> createState() => _EnrollCameraDialogState();
}

class _EnrollCameraDialogState extends State<_EnrollCameraDialog> {
  _EnrollStep _step = _EnrollStep.choice;
  String? _capturedDataUrl;
  String? _capturedBase64;
  String _source = '';

  @override
  void dispose() {
    CameraService.enroll.stopCamera();
    super.dispose();
  }

  Future<void> _startCamera() async {
    setState(() { _step = _EnrollStep.cameraStarting; _source = 'camera'; });
    try {
      if (CameraService.enroll.supportsLivePreview) {
        // Web: start live in-app stream
        await CameraService.enroll.startLiveCamera(frontFacing: true);
        if (mounted) setState(() { _step = _EnrollStep.cameraLive; });
      } else {
        // Mobile: open native OS camera
        final result = await CameraService.enroll.captureFromCamera(frontFacing: true);
        if (mounted) {
          if (result != null) {
            setState(() {
              _capturedBase64 = result.base64;
              _capturedDataUrl = result.dataUrl;
              _step = _EnrollStep.preview;
            });
          } else {
            setState(() { _step = _EnrollStep.choice; });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _step = _EnrollStep.choice; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Camera failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _capture() {
    final result = CameraService.enroll.captureFrame();
    CameraService.enroll.stopCamera();
    if (result == null) return;
    setState(() {
      _capturedBase64 = result.base64;
      _capturedDataUrl = result.dataUrl;
      _step = _EnrollStep.preview;
    });
  }

  Future<void> _pickFromGallery() async {
    setState(() { _source = 'gallery'; });
    final picked = await FileIoService.instance.pickImageFromGallery();
    if (!mounted || picked == null) return;
    setState(() {
      _capturedBase64 = picked.base64;
      _capturedDataUrl = picked.dataUrl;
      _step = _EnrollStep.preview;
    });
  }

  void _retake() {
    setState(() { _capturedBase64 = null; _capturedDataUrl = null; });
    if (_source == 'gallery') {
      setState(() { _step = _EnrollStep.choice; });
    } else {
      _startCamera();
    }
  }

  void _cancel() {
    CameraService.enroll.stopCamera();
    Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: const Color(0xFF854CF4),
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              child: Row(
                children: [
                  const Icon(Icons.face, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Enroll Face — ${widget.employeeName}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _cancel),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_step) {
                _EnrollStep.choice         => _ChoiceScreen(key: const ValueKey('choice'), onCamera: _startCamera, onGallery: _pickFromGallery),
                _EnrollStep.cameraStarting => _LoadingBody(key: const ValueKey('starting'), label: 'Starting camera…'),
                _EnrollStep.cameraLive     => _LiveViewfinder(key: const ValueKey('live'), onCapture: _capture, onCancel: _cancel),
                _EnrollStep.preview        => _CapturePreview(
                    key: const ValueKey('preview'),
                    dataUrl: _capturedDataUrl,
                    source: _source,
                    onRetake: _retake,
                    onConfirm: () => Navigator.pop(context, _capturedBase64),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Choice Screen ────────────────────────────────────────────────────────────

class _ChoiceScreen extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _ChoiceScreen({super.key, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('How would you like to add a photo?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Choose camera to take a live photo, or gallery to upload from your device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13)),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: _OptionCard(
            icon: Icons.camera_alt,
            label: 'Through Camera',
            description: 'Take a live photo using your camera',
            color: const Color(0xFF854CF4),
            onTap: onCamera,
          )),
          const SizedBox(width: 16),
          Expanded(child: _OptionCard(
            icon: Icons.photo_library,
            label: 'Through Gallery',
            description: 'Upload a photo from your device',
            color: const Color(0xFF04D3D3),
            onTap: onGallery,
          )),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  const _OptionCard({required this.icon, required this.label, required this.description, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 14),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ─── Loading Body ─────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  final String label;
  const _LoadingBody({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(color: Color(0xFF854CF4)),
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ])),
    );
  }
}

// ─── Live Viewfinder (web only) ───────────────────────────────────────────────

class _LiveViewfinder extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  const _LiveViewfinder({super.key, required this.onCapture, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: 320, child: Stack(fit: StackFit.expand, children: [
        buildCameraView(CameraService.enroll.viewType),
        Center(child: Container(
          width: 180, height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF854CF4), width: 3),
            borderRadius: BorderRadius.circular(110),
          ),
        )),
        Positioned(top: 12, left: 0, right: 0, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
          child: const Text('Align face inside the oval',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ))),
      ])),
      Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          GestureDetector(
            onTap: onCancel,
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back, color: Colors.white70, size: 26),
              SizedBox(height: 4),
              Text('Back', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          GestureDetector(onTap: onCapture, child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: const Color(0xFF854CF4),
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          )),
          const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.face, color: Colors.white70, size: 26),
            SizedBox(height: 4),
            Text('Front', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
      ),
    ]);
  }
}

// ─── Capture Preview ──────────────────────────────────────────────────────────

class _CapturePreview extends StatelessWidget {
  final String? dataUrl;
  final String source;
  final VoidCallback onRetake;
  final VoidCallback onConfirm;
  const _CapturePreview({super.key, required this.dataUrl, required this.source, required this.onRetake, required this.onConfirm});

  Uint8List? get _imageBytes {
    if (dataUrl == null) return null;
    try {
      final str = dataUrl!.contains(',') ? dataUrl!.split(',').last : dataUrl!;
      return base64Decode(str);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _imageBytes;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (bytes != null) ...[
          ClipOval(child: Image.memory(bytes, width: 160, height: 160, fit: BoxFit.cover)),
          const SizedBox(height: 16),
        ] else ...[
          const Icon(Icons.check_circle, color: Color(0xFF04D3D3), size: 80),
          const SizedBox(height: 16),
          const Text('Photo selected', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
        ],
        const Text('Use this photo for enrollment?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        const Text('Make sure your face is clearly visible and well-lit.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onRetake,
            icon: Icon(source == 'gallery' ? Icons.photo_library : Icons.refresh),
            label: Text(source == 'gallery' ? 'Choose Again' : 'Retake'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check),
            label: const Text('Enroll'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF854CF4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )),
        ]),
      ]),
    );
  }
}

// ─── Employee Tile ─────────────────────────────────────────────────────────────

class _EmployeeTile extends StatelessWidget {
  final Employee employee;
  final VoidCallback onDelete;
  final VoidCallback onEnroll;

  const _EmployeeTile({required this.employee, required this.onDelete, required this.onEnroll});

  @override
  Widget build(BuildContext context) {
    final photoBytes = _decodePhoto(employee.photoBase64);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: employee.isEnrolled
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF854CF4),
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: photoBytes != null
                    ? Image.memory(photoBytes, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _initialsAvatar())
                    : _initialsAvatar(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(employee.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF854CF4).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(employee.employeeId,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF854CF4), fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 3),
                Wrap(spacing: 8, children: [
                  if (employee.designation.isNotEmpty)
                    _chip(employee.designation, Colors.blue.shade50, Colors.blue.shade700),
                  if (employee.grade.isNotEmpty)
                    _chip('Grade ${employee.grade}', Colors.orange.shade50, Colors.orange.shade700),
                  if (employee.category.isNotEmpty)
                    _chip(employee.category, Colors.teal.shade50, Colors.teal.shade700),
                  if (employee.gender.isNotEmpty)
                    _chip(employee.gender, Colors.purple.shade50, Colors.purple.shade700),
                ]),
                if (employee.mobile.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(employee.mobile, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
                const SizedBox(height: 4),
                _EnrollBadge(enrolled: employee.isEnrolled),
              ]),
            ),
            Column(children: [
              IconButton(
                icon: Icon(
                  employee.isEnrolled ? Icons.camera_alt : Icons.add_a_photo,
                  color: const Color(0xFF04D3D3),
                ),
                tooltip: employee.isEnrolled ? 'Re-enroll Face' : 'Enroll Face',
                onPressed: onEnroll,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Uint8List? _decodePhoto(String? base64str) {
    if (base64str == null || base64str.isEmpty) return null;
    try {
      final str = base64str.contains(',') ? base64str.split(',').last : base64str;
      return base64Decode(str);
    } catch (_) {
      return null;
    }
  }

  Widget _initialsAvatar() => Container(
    color: employee.isEnrolled ? const Color(0xFF2E7D32) : const Color(0xFF854CF4),
    child: Center(
      child: Text(
        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    ),
  );

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
  );
}

class _EnrollBadge extends StatelessWidget {
  final bool enrolled;
  const _EnrollBadge({required this.enrolled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: enrolled
            ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
            : const Color(0xFFE65100).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          enrolled ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 12,
          color: enrolled ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
        ),
        const SizedBox(width: 4),
        Text(enrolled ? 'Face Enrolled' : 'Not Enrolled',
            style: TextStyle(
              fontSize: 11,
              color: enrolled ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              fontWeight: FontWeight.w600,
            )),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool isSearch;
  const _EmptyState({required this.onAdd, required this.isSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isSearch ? Icons.search_off : Icons.people_outline, size: 80, color: Colors.black26),
        const SizedBox(height: 16),
        Text(isSearch ? 'No employees match your search' : 'No employees yet',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(isSearch ? 'Try a different keyword' : 'Add your first employee to get started',
            style: const TextStyle(color: Colors.black54)),
        if (!isSearch) ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Employee'),
          ),
        ],
      ]),
    );
  }
}
