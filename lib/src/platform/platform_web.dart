// Consolidated web platform implementation.
// All web-specific helpers delegated to js_interop_bridge.
library platform_web;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_web_plugins/flutter_web_plugins.dart' as web_plugins;
import 'js_interop_bridge.dart';

// Re-export JS interop helpers for external use
export 'js_interop_bridge.dart' show
    getGlobalThis,
    getProperty,
    callMethod,
    allowInterop,
    dartify,
    jsify,
    rohdEmbed;

/// Getter for the global JavaScript object.
dynamic get globalThis => getGlobalThis();

/// Set a property on a JavaScript object.
void setProperty(dynamic target, String prop, dynamic value) {
  if (target is Map) {
    target[prop] = value;
    return;
  }
  // For JS objects, we need to use the JS interop
  try {
    final jsObj = target as dynamic;
    jsObj[prop] = jsify(value);
  } catch (_) {}
}

// ============================================================================
// File utilities (stub on web)
// ============================================================================

/// Stub implementation for web where direct file access isn't available.
Future<List<int>> readFileBytes(String path) async {
  throw UnsupportedError('readFileBytes is not supported on web');
}

// ============================================================================
// Embed helpers
// ============================================================================

void signalEmbedReadyImpl([Map<String, dynamic>? info]) {
  try {
    final payload = Map<String, dynamic>.from(info ?? {'initialized': true});
    payload['reloaded_in_gui'] = true;
    try {
      final console = getGlobalProperty('console');
      if (console != null) {
        callMethod(console, 'log',
            ['[embed] signalEmbedReady called', jsify(payload)]);
      }
    } catch (_) {}
    try {
      final cb = getGlobalProperty('__rohdEmbedReady');
      if (cb != null) {
        callMethod(cb, 'call', [
          getGlobalProperty('window'),
          jsify(payload)
        ]);
      }
    } catch (_) {}
  } catch (_) {}
}

void postMessageToHostImpl(Object message) {
  try {
    final post = getGlobalProperty('postRohd');
    if (post != null) {
      callMethod(post, 'call', [
        getGlobalProperty('window'),
        jsify(message as Map)
      ]);
      return;
    }
  } catch (_) {}
  try {
    final embed = getGlobalProperty('rohdEmbed');
    if (embed != null) {
      final postFn = getProperty(embed, 'postMessage');
      if (postFn != null) {
        callMethod(postFn, 'call', [embed, jsify(message as Map)]);
      }
    }
  } catch (_) {}
}

bool isShiftDownFromJsImpl() {
  try {
    final jsVal = getGlobalProperty('__shiftDown');
    if (jsVal == null) return false;
    final dartVal = dartify(jsVal);
    if (dartVal is bool) return dartVal;
    return jsVal.toString().toLowerCase() == 'true';
  } catch (_) {
    return false;
  }
}

// ============================================================================
// JS bindings helpers
// ============================================================================

void jsRequestAnimationFrame(void Function() cb) {
  try {
    requestAnimationFrame(allowInterop((_) {
      try {
        cb();
      } catch (_) {}
    }));
  } catch (_) {}
}

void jsRohdForceRepaint() {
  try {
    rohdForceRepaint();
  } catch (_) {}
}

// ============================================================================
// Window message helpers
// ============================================================================

typedef WindowMessageCallback = void Function(dynamic data);

void addWindowMessageListener(WindowMessageCallback cb) {
  try {
    callGlobalMethod('addEventListener', [
      'message',
      allowInterop((e) {
        try {
          final data = getProperty(e, 'data');
          if (data == null) return;
          if (data is String) {
            try {
              cb(json.decode(data));
              return;
            } catch (_) {}
          }
          try {
            final dartified = dartify(data);
            if (dartified != null) {
              cb(dartified);
              return;
            }
          } catch (_) {}
          cb(data);
        } catch (_) {}
      })
    ]);
  } catch (_) {}
}

void removeWindowMessageListener(WindowMessageCallback cb) {}

// ============================================================================
// Fetch helpers
// ============================================================================

/// Fetch bytes from a URI in the web environment. Returns a Uint8List.
Future<Uint8List> fetchBytes(String uri) async {
  try {
    final req = await promiseToFuture(
        callGlobalMethod('fetch', [uri]));
    final ab = await promiseToFuture(callMethod(req, 'arrayBuffer', []));
    // Convert to Uint8List by copying
    final jsList = callGlobalMethod('Uint8Array', [ab]);
    final len = getProperty(jsList, 'length') as int;
    final result = Uint8List(len);
    for (var i = 0; i < len; i++) {
      result[i] = getProperty(jsList, i) as int;
    }
    return result;
  } catch (e) {
    throw Exception('fetchBytes failed for $uri: $e');
  }
}

// ============================================================================
// URL strategy
// ============================================================================

void setUrlStrategySafe(dynamic strategy) {
  web_plugins.setUrlStrategy(strategy);
}

// Public embed API wrappers (moved from lib/embed.dart)
void signalEmbedReady([Map<String, dynamic>? info]) =>
    signalEmbedReadyImpl(info);
void postMessageToHost(Object message) => postMessageToHostImpl(message);
bool isShiftDownFromJs() => isShiftDownFromJsImpl();

// Re-export getGlobalProperty for external use
dynamic getGlobalPropertyExported(String name) => getGlobalProperty(name);
