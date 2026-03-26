import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CaptureResult {
  final String base64;
  final String dataUrl;
  const CaptureResult({required this.base64, required this.dataUrl});
}

/// Native (Android / iOS) camera service — uses image_picker.
/// On desktop platforms (Windows/Linux/macOS) captureFromCamera returns null.
class CameraService {
  // ignore: unused_field
  final String _id;
  CameraService._(this._id);

  static final CameraService scan = CameraService._('scan');
  static final CameraService enroll = CameraService._('enroll');

  bool get supportsLivePreview => false;
  bool get isStreaming => false;
  String get viewType => '';

  void init() {}
  Future<void> startLiveCamera({bool frontFacing = true}) async {}

  Future<CaptureResult?> captureFromCamera({bool frontFacing = true}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice:
          frontFacing ? CameraDevice.front : CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 720,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final b64 = base64Encode(bytes);
    return CaptureResult(base64: b64, dataUrl: 'data:image/jpeg;base64,$b64');
  }

  CaptureResult? captureFrame() => null;
  void stopCamera() {}
}
