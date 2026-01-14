// Facade for platform-specific implementations.
// Consumers should import this file to get platform helpers.
// Use `dart.library.html` to detect web (works with dart2js and legacy package:js).
// Use `dart.library.io` to detect native platforms.
//
// Everything (file utils, embed helpers, JS bindings, etc.) is now inlined
// in platform_io.dart and platform_web.dart for simplicity.
export 'platform_io.dart' if (dart.library.html) 'platform_web.dart';
