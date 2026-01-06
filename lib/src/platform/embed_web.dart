import 'src/platform/js_util_nojs.dart'
  if (dart.library.js) 'package:js/js_util.dart' as js_util;
// js_interop_bindings not required here; keep js_util usage

void signalEmbedReadyImpl([Map<String, dynamic>? info]) {
  try {
    final payload = Map<String, dynamic>.from(info ?? {'initialized': true});
    payload['reloaded_in_gui'] = true;
    try {
      try {
        // Use console.log if available
        final console = js_util.getProperty(js_util.globalThis, 'console');
        if (console != null) {
          js_util.callMethod(console, 'log',
              ['[embed] signalEmbedReady called', js_util.jsify(payload)]);
        }
      } catch (_) {}
    } catch (e) {
      // Keep minimal diagnostics for web interop failures.
      // Do not throw; these JS interop failures are non-fatal.
      // Use print to ensure visibility in browser console logs during debugging.
      // ignore: avoid_print
      print('[embed] console log failed: $e');
    }
    try {
      try {
        final cb = js_util.getProperty(js_util.globalThis, '__rohdEmbedReady');
        if (cb != null) {
          js_util.callMethod(cb, 'call', [
            js_util.getProperty(js_util.globalThis, 'window'),
            js_util.jsify(payload)
          ]);
        }
      } catch (_) {}
    } catch (e) {
      // ignore errors when calling embed ready callback; log for diagnostics
      // ignore: avoid_print
      print('[embed] callback invocation failed: $e');
    }
  } catch (e) {
    // Top-level embed ready failure — log for diagnostics
    // ignore: avoid_print
    print('[embed] signalEmbedReadyImpl failed: $e');
  }
}

void postMessageToHostImpl(Object message) {
  try {
    try {
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
    } catch (e) {
      // document postRohd invocation failures for diagnostics
      // ignore: avoid_print
      print('[embed] postRohd call failed: $e');
    }
    try {
      try {
        final embed = js_util.getProperty(js_util.globalThis, 'rohdEmbed');
        if (embed != null) {
          final postFn = js_util.getProperty(embed, 'postMessage');
          if (postFn != null) {
            js_util.callMethod(
                postFn, 'call', [embed, js_util.jsify(message as Map)]);
          }
        }
      } catch (_) {}
    } catch (e) {
      // postMessage via rohdEmbed failed — log for debugging
      // ignore: avoid_print
      print('[embed] rohdEmbed.postMessage failed: $e');
    }
  } catch (e) {
    // Top-level postMessage failure — log for diagnostics
    // ignore: avoid_print
    print('[embed] postMessageToHostImpl failed: $e');
  }
}

bool isShiftDownFromJsImpl() {
  try {
    final jsVal = js_util.getProperty(js_util.globalThis, '__shiftDown');
    if (jsVal == null) return false;
    // js_util.dartify will convert JS booleans to Dart bool
    try {
      final dartVal = js_util.dartify(jsVal);
      if (dartVal is bool) return dartVal;
    } catch (_) {}
    return jsVal.toString().toLowerCase() == 'true';
  } catch (e) {
    // if JS interop fails, assume shift is not held
    // ignore: avoid_print
    print('[embed] isShiftDownFromJsImpl JS access failed: $e');
    return false;
  }
}
