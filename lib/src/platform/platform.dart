// Facade for platform-specific implementations.
// Consumers should import this file to get platform helpers.
export 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';
