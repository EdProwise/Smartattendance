// Conditionally exports the correct camera preview widget builder.
export 'platform_camera_view_stub.dart'
    if (dart.library.html) 'platform_camera_view_web.dart';
