// Consolidated web platform implementation.
// All web-specific helpers and @JS bindings are inlined here.
// ignore_for_file: depend_on_referenced_packages
@JS()
library platform_web;

import 'dart:convert';
import 'dart:typed_data';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;
import 'package:flutter_web_plugins/flutter_web_plugins.dart' as web_plugins;

// ============================================================================
// Re-export js_util so consumers can use getProperty/callMethod/etc.
// ============================================================================

export 'package:js/js_util.dart';

// ============================================================================
// File utilities (stub on web)
// ============================================================================

/// Stub implementation for web where direct file access isn't available.
Future<List<int>> readFileBytes(String path) async {
  throw UnsupportedError('readFileBytes is not supported on web');
}

// ============================================================================
// @JS externals
// ============================================================================

@JS('rohdEmbed')
external dynamic get rohdEmbed;

@JS()
class RohdEmbed {
  external dynamic get onMessage;
  external void postMessage(dynamic msg);
}

@JS('rohdForceRepaint')
external void rohdForceRepaint();

@JS('postRohd')
external dynamic get postRohd;

@JS('requestAnimationFrame')
external void requestAnimationFrame(Function callback);

// ============================================================================
// Embed helpers
// ============================================================================

void signalEmbedReadyImpl([Map<String, dynamic>? info]) {
  try {
    final payload = Map<String, dynamic>.from(info ?? {'initialized': true});
    payload['reloaded_in_gui'] = true;
    try {
      final console = js_util.getProperty(js_util.globalThis, 'console');
      if (console != null) {
        js_util.callMethod(console, 'log',
            ['[embed] signalEmbedReady called', js_util.jsify(payload)]);
      }
    } catch (_) {}
    try {
      final cb = js_util.getProperty(js_util.globalThis, '__rohdEmbedReady');
      if (cb != null) {
        js_util.callMethod(cb, 'call', [
          js_util.getProperty(js_util.globalThis, 'window'),
          js_util.jsify(payload)
        ]);
      }
    } catch (_) {}
  } catch (_) {}
}

void postMessageToHostImpl(Object message) {
  try {
    final post = js_util.getProperty(js_util.globalThis, 'postRohd');
    if (post != null) {
      js_util.callMethod(post, 'call', [
        js_util.getProperty(js_util.globalThis, 'window'),
        js_util.jsify(message as Map)
      ]);
      return;
    }
  } catch (_) {}
  try {
    final embed = js_util.getProperty(js_util.globalThis, 'rohdEmbed');
    if (embed != null) {
      final postFn = js_util.getProperty(embed, 'postMessage');
      if (postFn != null) {
        js_util
            .callMethod(postFn, 'call', [embed, js_util.jsify(message as Map)]);
      }
    }
  } catch (_) {}
}

bool isShiftDownFromJsImpl() {
  try {
    final jsVal = js_util.getProperty(js_util.globalThis, '__shiftDown');
    if (jsVal == null) return false;
    final dartVal = js_util.dartify(jsVal);
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
    requestAnimationFrame(js_util.allowInterop((_) {
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
    js_util.callMethod(js_util.globalThis, 'addEventListener', [
      'message',
      js_util.allowInterop((e) {
        try {
          final data = js_util.getProperty(e, 'data');
          if (data == null) return;
          if (data is String) {
            try {
              cb(json.decode(data));
              return;
            } catch (_) {}
          }
          try {
            final dartified = js_util.dartify(data);
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
    final req = await js_util.promiseToFuture(
        js_util.callMethod(js_util.globalThis, 'fetch', [uri]));
    final ab = await js_util
        .promiseToFuture(js_util.callMethod(req, 'arrayBuffer', []));
    // Convert to Uint8List by copying
    final jsList = js_util.callMethod(js_util.globalThis, 'Uint8Array', [ab]);
    final len = js_util.getProperty(jsList, 'length') as int;
    final result = Uint8List(len);
    for (var i = 0; i < len; i++) {
      result[i] = js_util.getProperty(jsList, i) as int;
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
