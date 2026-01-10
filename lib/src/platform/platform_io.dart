// Consolidated IO/native platform implementation.
// All no-JS shims and native helpers are inlined here.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;

// ============================================================================
// File utilities
// ============================================================================

/// Read file bytes on native platforms.
Future<List<int>> readFileBytes(String path) async {
  final file = File(path);
  return await file.readAsBytes();
}

/// Fetch bytes for native platforms. Supports file:// and http(s) URLs.
Future<Uint8List> fetchBytes(String uri) async {
  try {
    final u = Uri.parse(uri);
    if (u.scheme == 'file' || u.scheme.isEmpty) {
      final path = u.scheme == 'file' ? u.toFilePath() : uri;
      final bytes = await readFileBytes(path);
      return Uint8List.fromList(bytes);
    } else if (u.scheme == 'http' || u.scheme == 'https') {
      final client = HttpClient();
      final req = await client.getUrl(u);
      final resp = await req.close();
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final bytes = await consolidateHttpClientResponseBytes(resp);
      return Uint8List.fromList(bytes);
    } else {
      throw UnsupportedError('Unsupported URI scheme: ${u.scheme}');
    }
  } catch (e) {
    rethrow;
  }
}

// ============================================================================
// Embed helpers (no-op on native)
// ============================================================================

void signalEmbedReadyImpl([Map<String, dynamic>? info]) {}

void postMessageToHostImpl(Object message) {}

bool isShiftDownFromJsImpl() => false;

// ============================================================================
// JS bindings helpers (no-op on native)
// ============================================================================

void jsRequestAnimationFrame(void Function() cb) {}

void jsRohdForceRepaint() {}

// ============================================================================
// Window message helpers (no-op on native)
// ============================================================================

typedef WindowMessageCallback = void Function(dynamic data);

void addWindowMessageListener(WindowMessageCallback cb) {}

void removeWindowMessageListener(WindowMessageCallback cb) {}

// ============================================================================
// URL strategy (no-op on native)
// ============================================================================

void setUrlStrategySafe(dynamic strategy) {}

// ============================================================================
// js_util-like shim (for code that uses getProperty/callMethod/etc.)
// ============================================================================

final _global = <String, dynamic>{};

dynamic get globalThis => _global;

dynamic getProperty(dynamic target, String prop) {
  try {
    if (target is Map) return target[prop];
    return null;
  } catch (_) {
    return null;
  }
}

void setProperty(dynamic target, String prop, dynamic value) {
  try {
    if (target is Map) target[prop] = value;
  } catch (_) {}
}

dynamic callMethod(dynamic target, String method, List args) {
  try {
    final fn = getProperty(target, method);
    if (fn is Function) return Function.apply(fn, args);
  } catch (_) {}
  return null;
}

dynamic allowInterop(Function f) => f;

dynamic dartify(dynamic o) => o;

dynamic jsify(dynamic o) => o;

// ============================================================================
// @JS externals stubs (no-op on native)
// ============================================================================

dynamic get rohdEmbed => null;

class RohdEmbed {
  dynamic get onMessage => null;
  void postMessage(dynamic msg) {}
}

void rohdForceRepaint() {}

dynamic get postRohd => null;

void requestAnimationFrame(Function callback) {
  Future.microtask(() => callback(0));
}

// Public embed API wrappers (moved from lib/embed.dart)
void signalEmbedReady([Map<String, dynamic>? info]) =>
    signalEmbedReadyImpl(info);
void postMessageToHost(Object message) => postMessageToHostImpl(message);
bool isShiftDownFromJs() => isShiftDownFromJsImpl();
