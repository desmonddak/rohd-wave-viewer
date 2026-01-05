import 'dart:io';

/// Read file bytes on native platforms.
Future<List<int>> readFileBytes(String path) async {
  final file = File(path);
  return await file.readAsBytes();
}
