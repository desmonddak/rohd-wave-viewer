// No-op implementations for native/IO builds where JS interop is unavailable.
void jsRequestAnimationFrame(void Function() cb) {
  // No-op on native
}

void jsRohdForceRepaint() {
  // No-op on native
}
