import 'package:flutter/widgets.dart';

/// Returns an empty placeholder — live camera preview is not supported
/// on this platform (use image_picker on mobile instead).
Widget buildCameraView(String viewType) => const SizedBox.shrink();
