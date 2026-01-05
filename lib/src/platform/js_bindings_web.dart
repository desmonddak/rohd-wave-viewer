import 'package:js/js_util.dart' as js_util;
import 'js_interop_bindings.dart' as binds;

// Call a browser requestAnimationFrame with a Dart callback.
void jsRequestAnimationFrame(void Function() cb) {
  try {
    binds.requestAnimationFrame(js_util.allowInterop((_) {
      try {
        cb();
      } catch (_) {}
    }));
  } catch (_) {}
}

// Call into the JS function that the web bootstrap exposes to force a repaint.
void jsRohdForceRepaint() {
  try {
    try {
      binds.rohdForceRepaint();
    } catch (_) {
      // fallback: do nothing if not present
    }
  } catch (_) {}
}
