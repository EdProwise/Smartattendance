import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/file_io_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  bool _cameraActive = false;
  bool _cameraLoading = false;
  bool _processingFrame = false;
  Map<String, dynamic>? _result;
  String? _capturedDataUrl;
  String _statusMessage = 'Align your face in the oval';
  int _scanAttempts = 0;

  Timer? _scanTimer;
  bool _initialized = false;

  String _scanType = 'checkin';
  String? _schoolId;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    CameraService.scan.init();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _scanType = extra?['type'] as String? ?? 'checkin';
    _schoolId = extra?['schoolId'] as String?;
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _pulseCtrl.dispose();
    CameraService.scan.stopCamera();
    super.dispose();
  }

  // ─── Camera ──────────────────────────────────────────────────────────────────

  Future<void> _startCamera() async {
    if (!mounted) return;
    setState(() {
      _cameraLoading = true;
      _statusMessage = 'Starting camera...';
    });
    try {
      if (CameraService.scan.supportsLivePreview) {
        await CameraService.scan.startLiveCamera(frontFacing: true);
        if (mounted) {
          setState(() {
            _cameraActive = true;
            _cameraLoading = false;
            _statusMessage = 'Align your face in the oval';
          });
          _beginAutoScan();
        }
      } else {
        // Native: open OS camera once and process result
        final result =
            await CameraService.scan.captureFromCamera(frontFacing: true);
        if (mounted) {
          setState(() {
            _cameraLoading = false;
          });
          if (result != null) {
            setState(() => _capturedDataUrl = result.dataUrl);
            await _processScan(result.base64);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraLoading = false);
        _showError(
            'Camera access denied. Please allow camera permission and try again.');
      }
    }
  }

  // ─── Auto-scan timer ─────────────────────────────────────────────────────────

  void _beginAutoScan() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 2000),
      (_) => _autoScanTick(),
    );
  }

  Future<void> _autoScanTick() async {
    if (!mounted || _processingFrame || _result != null) return;
    final frame = await CameraService.scan.captureFrame();
    if (frame == null) return;
    await _processScan(frame.base64, capturedDataUrl: frame.dataUrl);
  }

  // ─── Process / API ───────────────────────────────────────────────────────────

  Future<void> _processScan(String base64Image,
      {String? capturedDataUrl}) async {
    if (!mounted || _processingFrame) return;
    setState(() {
      _processingFrame = true;
      _scanAttempts++;
    });
    try {
      final result = await ApiService.scanFace(
        base64Image,
        type: _scanType,
        schoolId: _schoolId,
      );
      if (!mounted) return;
      final matched = result['matched'] as bool? ?? false;
      if (matched) {
        _scanTimer?.cancel();
        CameraService.scan.stopCamera();
        setState(() {
          _result = result;
          _processingFrame = false;
          _cameraActive = false;
          if (capturedDataUrl != null) _capturedDataUrl = capturedDataUrl;
        });
      } else {
        setState(() {
          _processingFrame = false;
          _statusMessage = 'No match — keep facing the camera';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _processingFrame = false;
          _statusMessage = 'Align your face in the oval';
        });
      }
    }
  }

  // ─── Gallery fallback ────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    _scanTimer?.cancel();
    final picked = await FileIoService.instance.pickImageFromGallery();
    if (!mounted) return;
    if (picked == null) {
      if (_cameraActive) _beginAutoScan();
      return;
    }
    CameraService.scan.stopCamera();
    setState(() {
      _capturedDataUrl = picked.dataUrl;
      _cameraActive = false;
    });
    await _processScan(picked.base64);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _cancel() {
    _scanTimer?.cancel();
    CameraService.scan.stopCamera();
    if (mounted) context.pop();
  }

  void _reset() {
    _scanTimer?.cancel();
    CameraService.scan.stopCamera();
    setState(() {
      _result = null;
      _capturedDataUrl = null;
      _cameraActive = false;
      _processingFrame = false;
      _scanAttempts = 0;
      _statusMessage = 'Align your face in the oval';
    });
    _startCamera();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Result screen ──────────────────────────────────────────────────────────
    if (_result != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0FF),
        appBar: AppBar(
          title: Text(_scanType == 'checkout' ? 'Check Out' : 'Check In'),
          automaticallyImplyLeading: false,
        ),
        body: _ResultView(
          result: _result!,
          capturedDataUrl: _capturedDataUrl,
          onReset: _reset,
          onDone: _cancel,
        ),
      );
    }

    // ── Camera loading ─────────────────────────────────────────────────────────
    if (_cameraLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(_scanType == 'checkout' ? 'Check Out' : 'Check In'),
          leading:
              IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF854CF4)),
              SizedBox(height: 20),
              Text('Starting camera…',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    // ── Live in-app camera (web) ───────────────────────────────────────────────
    if (_cameraActive && CameraService.scan.supportsLivePreview) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _LiveScanView(
            scanType: _scanType,
            statusMessage: _statusMessage,
            processingFrame: _processingFrame,
            scanAttempts: _scanAttempts,
            pulseAnim: _pulseAnim,
            onGallery: _pickFromGallery,
            onCancel: _cancel,
          ),
        ),
      );
    }

    // ── Native / retry fallback ────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: Text(_scanType == 'checkout' ? 'Check Out' : 'Check In'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
      ),
      body: _processingFrame
          ? const _ScanningView()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF854CF4).withValues(alpha: 0.08),
                        border: Border.all(
                          color:
                              const Color(0xFF854CF4).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.face_retouching_natural,
                          size: 80, color: Color(0xFF854CF4)),
                    ),
                    const SizedBox(height: 28),
                    const Text('Face Attendance',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Point your front camera at your face to mark attendance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startCamera,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Open Camera'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload from Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─── Live Camera Viewfinder (web) ─────────────────────────────────────────────

class _LiveScanView extends StatelessWidget {
  final String scanType;
  final String statusMessage;
  final bool processingFrame;
  final int scanAttempts;
  final Animation<double> pulseAnim;
  final VoidCallback onGallery;
  final VoidCallback onCancel;

  const _LiveScanView({
    required this.scanType,
    required this.statusMessage,
    required this.processingFrame,
    required this.scanAttempts,
    required this.pulseAnim,
    required this.onGallery,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Camera feed ──────────────────────────────────────────────────────
        ClipRect(
          child: CameraService.scan.buildPreview(),
        ),

        // ── Semi-dark corners overlay ────────────────────────────────────────
        IgnorePointer(
          child: CustomPaint(
            painter: _OvalCutoutPainter(processingFrame: processingFrame),
          ),
        ),

        // ── Oval guide ───────────────────────────────────────────────────────
        Center(
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: processingFrame ? 1.0 : pulseAnim.value,
              child: Container(
                width: 240,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: processingFrame
                        ? Colors.orange
                        : const Color(0xFF854CF4),
                    width: 3.5,
                  ),
                  borderRadius: BorderRadius.circular(120),
                ),
              ),
            ),
          ),
        ),

        // ── Top bar ──────────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: onCancel,
                ),
                const Spacer(),
                Text(
                  scanType == 'checkout' ? 'Check Out' : 'Check In',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon:
                      const Icon(Icons.photo_library_outlined, color: Colors.white70),
                  onPressed: onGallery,
                  tooltip: 'Upload from Gallery',
                ),
              ],
            ),
          ),
        ),

        // ── Status chip ──────────────────────────────────────────────────────
        Positioned(
          top: 72,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(statusMessage + processingFrame.toString()),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: processingFrame
                      ? Colors.orange.withValues(alpha: 0.82)
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (processingFrame) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text('Verifying face…',
                          style:
                              TextStyle(color: Colors.white, fontSize: 13.5)),
                    ] else ...[
                      const Icon(Icons.face_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(statusMessage,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Bottom scan indicator ─────────────────────────────────────────────
        Positioned(
          bottom: 36,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sensors_rounded,
                      color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    scanAttempts == 0
                        ? 'Auto-scanning…'
                        : 'Scanned $scanAttempts frame(s)',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Oval cutout painter ─────────────────────────────────────────────────────

class _OvalCutoutPainter extends CustomPainter {
  final bool processingFrame;
  const _OvalCutoutPainter({required this.processingFrame});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 246,
      height: 306,
    );
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OvalCutoutPainter old) =>
      old.processingFrame != processingFrame;
}

// ─── Scanning Indicator ───────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 24),
          Text('Scanning face…', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Please wait', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

// ─── Result Screen ────────────────────────────────────────────────────────────

Widget _buildImageFromDataUrl(String dataUrl) {
  if (dataUrl.startsWith('data:')) {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex != -1) {
      final bytes = base64Decode(dataUrl.substring(commaIndex + 1));
      return Image.memory(bytes, width: 120, height: 120, fit: BoxFit.cover);
    }
  }
  return Image.network(dataUrl, width: 120, height: 120, fit: BoxFit.cover);
}

class _ResultView extends StatelessWidget {
  final Map<String, dynamic> result;
  final String? capturedDataUrl;
  final VoidCallback onReset;
  final VoidCallback onDone;

  const _ResultView({
    required this.result,
    required this.capturedDataUrl,
    required this.onReset,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final matched = result['matched'] as bool? ?? false;
    final alreadyMarked = result['alreadyMarked'] as bool? ?? false;
    final message = result['message'] as String? ?? '';
    final employee = result['employee'] as Map<String, dynamic>?;

    final Color cardColor;
    final IconData cardIcon;
    final String cardTitle;

    if (matched && !alreadyMarked) {
      cardColor = const Color(0xFF2E7D32);
      cardIcon = Icons.check_circle_rounded;
      cardTitle = 'Attendance Marked!';
    } else if (matched && alreadyMarked) {
      cardColor = const Color(0xFFF57C00);
      cardIcon = Icons.info_rounded;
      cardTitle = 'Already Marked';
    } else {
      cardColor = const Color(0xFFC62828);
      cardIcon = Icons.cancel_rounded;
      cardTitle = 'Not Recognised';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (capturedDataUrl != null) ...[
              ClipOval(child: _buildImageFromDataUrl(capturedDataUrl!)),
              const SizedBox(height: 24),
            ],
            Icon(cardIcon, color: cardColor, size: 68),
            const SizedBox(height: 16),
            Text(
              cardTitle,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cardColor),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            if (employee != null) ...[
              const SizedBox(height: 20),
              Card(
                color: cardColor.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(Icons.badge, 'Name',
                          employee['name'] as String? ?? ''),
                      if ((employee['department'] as String?)?.isNotEmpty ==
                          true)
                        _InfoRow(Icons.apartment, 'Department',
                            employee['department'] as String),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan Again'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
