/// Stub implementation for web where direct file access isn't available.
Future<List<int>> readFileBytes(String path) async {
  throw UnsupportedError('readFileBytes is not supported on web');
}
