// Stub camera service — used on unsupported platforms.
// Web overrides this with camera_service_web.dart
// Mobile (Android/iOS) overrides with camera_service_native.dart

class CaptureResult {
  final String base64;
  final String dataUrl;
  const CaptureResult({required this.base64, required this.dataUrl});
}

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
  Future<CaptureResult?> captureFromCamera({bool frontFacing = true}) async => null;
  CaptureResult? captureFrame() => null;
  void stopCamera() {}
}
