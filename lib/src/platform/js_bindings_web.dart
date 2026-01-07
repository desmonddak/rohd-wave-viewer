import 'platform.dart' as plat;

// Call a browser requestAnimationFrame with a Dart callback.
void jsRequestAnimationFrame(void Function() cb) {
  try {
    plat.requestAnimationFrame(plat.allowInterop((_) {
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
      plat.rohdForceRepaint();
    } catch (_) {
      // fallback: do nothing if not present
    }
  } catch (_) {}
}
