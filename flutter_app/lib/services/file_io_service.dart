// Conditionally exports the correct file I/O service for the current platform.
export 'file_io_service_stub.dart'
    if (dart.library.html) 'file_io_service_web.dart'
    if (dart.library.io) 'file_io_service_native.dart';
