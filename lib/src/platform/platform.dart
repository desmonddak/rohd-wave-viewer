// Facade for platform-specific implementations.
// Consumers should import this file to get platform helpers.
// Use `dart.library.js` to select the true JS runtime (dart2js). This avoids
// importing `package:js` when compiling to WebAssembly (dart2wasm).
//
// Everything (file utils, embed helpers, JS bindings, etc.) is now inlined
// in platform_io.dart and platform_web.dart for simplicity.
export 'platform_io.dart' if (dart.library.js) 'platform_web.dart';
