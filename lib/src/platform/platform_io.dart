// Consolidated IO/native platform implementation.
// All no-JS shims and native helpers are inlined here.
import 'dart:io';

// ============================================================================
// File utilities
// ============================================================================

/// Read file bytes on native platforms.
Future<List<int>> readFileBytes(String path) async {
  final file = File(path);
  return await file.readAsBytes();
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
void signalEmbedReady([Map<String, dynamic>? info]) => signalEmbedReadyImpl(info);
void postMessageToHost(Object message) => postMessageToHostImpl(message);
bool isShiftDownFromJs() => isShiftDownFromJsImpl();
