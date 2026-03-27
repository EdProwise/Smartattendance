import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

class CaptureResult {
  final String base64;
  final String dataUrl;
  const CaptureResult({required this.base64, required this.dataUrl});
}

/// Native (Android / iOS) camera service — uses the Flutter camera package
/// for in-app live preview and periodic frame capture.
/// On desktop platforms (Windows/Linux/macOS) preview is not supported.
class CameraService {
  // ignore: unused_field
  final String _id;
  CameraController? _controller;

  CameraService._(this._id);

  static final CameraService scan = CameraService._('scan');
  static final CameraService enroll = CameraService._('enroll');

  bool get supportsLivePreview => Platform.isAndroid || Platform.isIOS;
  bool get isStreaming => _controller?.value.isInitialized == true;
  String get viewType => '';

  void init() {}

  Future<void> startLiveCamera({bool frontFacing = true}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await stopCamera();
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final lensDir =
        frontFacing ? CameraLensDirection.front : CameraLensDirection.back;
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == lensDir,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
  }

  /// Returns a [CameraPreview] widget for displaying the live viewfinder.
  Widget buildPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(_controller!);
  }

  /// Captures the current frame as a JPEG and returns base64 + data-URL.
  Future<CaptureResult?> captureFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      final b64 = base64Encode(bytes);
      return CaptureResult(base64: b64, dataUrl: 'data:image/jpeg;base64,$b64');
    } catch (_) {
      return null;
    }
  }

  /// Not used on native when [supportsLivePreview] is true.
  Future<CaptureResult?> captureFromCamera({bool frontFacing = true}) async =>
      null;

  Future<void> stopCamera() async {
    await _controller?.dispose();
    _controller = null;
  }
}
