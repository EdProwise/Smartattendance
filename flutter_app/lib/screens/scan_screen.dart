import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/file_io_service.dart';
import '../widgets/platform_camera_view.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _cameraActive = false;
  bool _cameraLoading = false;
  bool _scanning = false;
  Map<String, dynamic>? _result;
  String? _capturedDataUrl;

  @override
  void initState() {
    super.initState();
    CameraService.scan.init();
  }

  @override
  void dispose() {
    CameraService.scan.stopCamera();
    super.dispose();
  }

  Future<void> _startCamera() async {
    setState(() { _cameraLoading = true; });
    try {
      if (CameraService.scan.supportsLivePreview) {
        // Web: show live in-app viewfinder
        await CameraService.scan.startLiveCamera(frontFacing: true);
        if (mounted) setState(() { _cameraActive = true; _cameraLoading = false; });
      } else {
        // Mobile: open native OS camera, get image immediately
        final result = await CameraService.scan.captureFromCamera(frontFacing: true);
        if (mounted) {
          setState(() { _cameraLoading = false; });
          if (result != null) {
            setState(() { _capturedDataUrl = result.dataUrl; });
            await _processScan(result.base64);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _cameraLoading = false; });
        _showError('Camera access denied. Please allow camera permission and try again.');
      }
    }
  }

  void _captureAndScan() {
    final result = CameraService.scan.captureFrame();
    CameraService.scan.stopCamera();
    if (result == null) {
      _showError('Failed to capture image. Please try again.');
      return;
    }
    setState(() {
      _cameraActive = false;
      _capturedDataUrl = result.dataUrl;
    });
    _processScan(result.base64);
  }

  void _stopCamera() {
    CameraService.scan.stopCamera();
    setState(() { _cameraActive = false; _cameraLoading = false; });
  }

  Future<void> _pickFromGallery() async {
    final picked = await FileIoService.instance.pickImageFromGallery();
    if (picked == null) return;
    setState(() { _capturedDataUrl = picked.dataUrl; });
    await _processScan(picked.base64);
  }

  Future<void> _processScan(String base64Image) async {
    setState(() { _scanning = true; _result = null; });
    try {
      final result = await ApiService.scanFace(base64Image);
      if (mounted) setState(() { _result = result; _scanning = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _scanning = false; });
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _reset() {
    CameraService.scan.stopCamera();
    setState(() {
      _result = null;
      _capturedDataUrl = null;
      _cameraActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          if (_cameraActive)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Stop Camera',
              onPressed: _stopCamera,
            ),
        ],
      ),
      body: _scanning
          ? const _ScanningView()
          : _result != null
              ? _ResultView(
                  result: _result!,
                  capturedDataUrl: _capturedDataUrl,
                  onReset: _reset,
                )
              : _cameraActive
                  ? _CameraViewfinderView(onCapture: _captureAndScan, onCancel: _stopCamera)
                  : _CaptureView(
                      cameraLoading: _cameraLoading,
                      onCamera: _startCamera,
                      onGallery: _pickFromGallery,
                    ),
    );
  }
}

// ─── Live Camera Viewfinder (web only) ───────────────────────────────────────

class _CameraViewfinderView extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  const _CameraViewfinderView({required this.onCapture, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: buildCameraView(CameraService.scan.viewType),
              ),
              Center(
                child: Container(
                  width: 240,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF854CF4), width: 3),
                    borderRadius: BorderRadius.circular(120),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Align your face inside the oval',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: onCancel,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, color: Colors.white70, size: 28),
                    SizedBox(height: 4),
                    Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onCapture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: const Color(0xFF854CF4),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.face, color: Colors.white70, size: 28),
                  SizedBox(height: 4),
                  Text('Front', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Capture Options ──────────────────────────────────────────────────────────

class _CaptureView extends StatelessWidget {
  final bool cameraLoading;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _CaptureView({
    required this.cameraLoading,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF854CF4).withValues(alpha: 0.08),
                border: Border.all(
                  color: const Color(0xFF854CF4).withValues(alpha: 0.3),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              child: const Icon(Icons.face_retouching_natural,
                  size: 100, color: Color(0xFF854CF4)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Mark Your Attendance',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open camera to take a live selfie, or upload a photo to scan your face.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cameraLoading ? null : onCamera,
                icon: cameraLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(cameraLoading ? 'Opening Camera...' : 'Open Camera'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onGallery,
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
    );
  }
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
          Text('Scanning face...', style: TextStyle(fontSize: 18)),
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

  const _ResultView({
    required this.result,
    required this.capturedDataUrl,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final matched = result['matched'] as bool? ?? false;
    final alreadyMarked = result['alreadyMarked'] as bool? ?? false;
    final message = result['message'] as String? ?? '';
    final employee = result['employee'] as Map<String, dynamic>?;

    Color cardColor;
    IconData cardIcon;
    String cardTitle;

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
      cardTitle = 'Not Recognized';
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
            Icon(cardIcon, color: cardColor, size: 64),
            const SizedBox(height: 16),
            Text(cardTitle,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cardColor)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black87)),
            if (employee != null) ...[
              const SizedBox(height: 20),
              Card(
                color: cardColor.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(Icons.badge, 'Name', employee['name'] as String? ?? ''),
                      if ((employee['department'] as String?)?.isNotEmpty == true)
                        _InfoRow(Icons.apartment, 'Department',
                            employee['department'] as String),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan Another'),
              ),
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
