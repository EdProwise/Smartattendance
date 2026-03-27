// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/widgets.dart';

class CaptureResult {
  final String base64;
  final String dataUrl;
  const CaptureResult({required this.base64, required this.dataUrl});
}

/// Web implementation — uses getUserMedia + HtmlElementView.
class CameraService {
  final String _viewType;
  html.MediaStream? _stream;
  late final html.VideoElement _video;

  CameraService._(this._viewType) {
    _video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..setAttribute('playsinline', 'true');
  }

  static final CameraService scan =
      CameraService._('smart-attendance-camera-scan');
  static final CameraService enroll =
      CameraService._('smart-attendance-camera-enroll');

  static bool _registeredScan = false;
  static bool _registeredEnroll = false;

  bool get supportsLivePreview => true;
  bool get isStreaming => _stream != null;
  String get viewType => _viewType;

  void init() {
    if (_viewType == scan._viewType && _registeredScan) return;
    if (_viewType == enroll._viewType && _registeredEnroll) return;

    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );

    if (_viewType == scan._viewType) _registeredScan = true;
    if (_viewType == enroll._viewType) _registeredEnroll = true;
  }

  Future<void> startLiveCamera({bool frontFacing = true}) async {
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

  /// Not used on web — camera is captured through startLiveCamera + captureFrame.
  Future<CaptureResult?> captureFromCamera({bool frontFacing = true}) async =>
      null;

  /// Returns an [HtmlElementView] for displaying the live camera feed.
  Widget buildPreview() => HtmlElementView(viewType: _viewType);

  Future<CaptureResult?> captureFrame() async {
    if (_video.videoWidth == 0 || _video.videoHeight == 0) return null;
    final canvas = html.CanvasElement(
      width: _video.videoWidth,
      height: _video.videoHeight,
    );
    final ctx = canvas.context2D;
    ctx.translate(_video.videoWidth.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(_video, 0, 0);
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    const prefix = 'data:image/jpeg;base64,';
    if (!dataUrl.startsWith(prefix)) return null;
    return CaptureResult(base64: dataUrl.substring(prefix.length), dataUrl: dataUrl);
  }

  void stopCamera() {
    _stream?.getTracks().forEach((t) => t.stop());
    _stream = null;
    _video.srcObject = null;
  }
}
