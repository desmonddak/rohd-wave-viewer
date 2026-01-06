// No-JS shim for environments where `dart:js`/`package:js` is unavailable
// (for example, when compiling to WebAssembly). This file provides the
// same symbols as `js_interop_bindings.dart` but with safe no-op
// implementations so the code can compile in a non-JS interop target.

// Access global property rohdEmbed (may be null)
dynamic get rohdEmbed => null;

// Minimal stub of RohdEmbed used in the UI code. Methods are no-ops.
class RohdEmbed {
  dynamic get onMessage => null;
  void postMessage(dynamic msg) {}
}

// Global function rohdForceRepaint (no-op)
void rohdForceRepaint() {}

// Window.postRohd shim (no-op)
dynamic get postRohd => null;

// requestAnimationFrame fallback (calls Dart async microtask)
void requestAnimationFrame(Function callback) {
  Future.microtask(() => callback(0));
}
