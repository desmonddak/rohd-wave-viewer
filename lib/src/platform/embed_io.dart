// Native no-op implementations for embed helpers used on web.
void signalEmbedReadyImpl([Map<String, dynamic>? info]) {
  // no-op on native
}

void postMessageToHostImpl(Object message) {
  // no-op on native
}

bool isShiftDownFromJsImpl() {
  return false;
}
