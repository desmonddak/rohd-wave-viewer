typedef WindowMessageCallback = void Function(dynamic event);

void addWindowMessageListener(WindowMessageCallback cb) {
  // No-op on native platforms
}

void removeWindowMessageListener(WindowMessageCallback cb) {
  // No-op on native platforms
}
