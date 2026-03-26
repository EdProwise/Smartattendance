// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

class WebCameraService {
  final String _viewType;
  html.MediaStream? _stream;

  // Pre-created video element — same instance returned by the factory every time.
  late final html.VideoElement _video;

  WebCameraService._(this._viewType) {
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..setAttribute('playsinline', 'true');
  }

  static final WebCameraService scan =
      WebCameraService._('smart-attendance-camera-scan');
  static final WebCameraService enroll =
      WebCameraService._('smart-attendance-camera-enroll');

  static bool _registeredScan = false;
  static bool _registeredEnroll = false;

  /// Registers the HtmlElementView factory for this instance.
  void ensureRegistered() {
    if (_viewType == scan._viewType && _registeredScan) return;
    if (_viewType == enroll._viewType && _registeredEnroll) return;

    // Always return the pre-created element so srcObject assignments are stable.
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );

    if (_viewType == scan._viewType) _registeredScan = true;
    if (_viewType == enroll._viewType) _registeredEnroll = true;
  }

  String get viewType => _viewType;

  /// Starts the camera stream and attaches it to the video element.
  Future<void> startCamera({bool frontFacing = true}) async {
    _stream = await html.window.navigator.mediaDevices?.getUserMedia({
      'video': {
        'facingMode': frontFacing ? 'user' : 'environment',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
      'audio': false,
    });
    if (_stream != null) {
      _video.srcObject = _stream;
      await _video.play();
    }
  }

  /// Captures a JPEG frame and returns base64 string (no data URL prefix).
  String? captureFrame() {
    if (_video.videoWidth == 0 || _video.videoHeight == 0) return null;
    final canvas = html.CanvasElement(
      width: _video.videoWidth,
      height: _video.videoHeight,
    );
    final ctx = canvas.context2D;
    // Mirror for front camera
    ctx.translate(_video.videoWidth.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(_video, 0, 0);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    const prefix = 'data:image/jpeg;base64,';
    if (dataUrl.startsWith(prefix)) return dataUrl.substring(prefix.length);
    return null;
  }

  /// Returns frame as data URL (for image preview).
  String? captureFrameAsDataUrl() {
    if (_video.videoWidth == 0 || _video.videoHeight == 0) return null;
    final canvas = html.CanvasElement(
      width: _video.videoWidth,
      height: _video.videoHeight,
    );
    final ctx = canvas.context2D;
    ctx.translate(_video.videoWidth.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(_video, 0, 0);
    return canvas.toDataUrl('image/jpeg', 0.85);
  }

  /// Stops all camera tracks.
  void stopCamera() {
    _stream?.getTracks().forEach((t) => t.stop());
    _stream = null;
    _video.srcObject = null;
  }

  bool get isStreaming => _stream != null;
}
