// Platform-aware file read helper. Uses a native implementation on IO
// platforms and a stub on web so the import doesn't break web builds.
export 'file_utils_io.dart' if (dart.library.html) 'file_utils_stub.dart';
