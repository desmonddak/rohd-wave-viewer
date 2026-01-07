import 'platform.dart' as plat;
// Uses the unified platform facade for JS utilities and externals.

void signalEmbedReadyImpl([Map<String, dynamic>? info]) {
  try {
    final payload = Map<String, dynamic>.from(info ?? {'initialized': true});
    payload['reloaded_in_gui'] = true;
    try {
      try {
        // Use console.log if available
        final console = plat.getProperty(plat.globalThis, 'console');
        if (console != null) {
          plat.callMethod(console, 'log',
              ['[embed] signalEmbedReady called', plat.jsify(payload)]);
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
        final cb = plat.getProperty(plat.globalThis, '__rohdEmbedReady');
        if (cb != null) {
          plat.callMethod(cb, 'call', [
            plat.getProperty(plat.globalThis, 'window'),
            plat.jsify(payload)
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
          final post = plat.getProperty(plat.globalThis, 'postRohd');
          if (post != null) {
            plat.callMethod(post, 'call', [
              plat.getProperty(plat.globalThis, 'window'),
              plat.jsify(message as Map)
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
          final embed = plat.getProperty(plat.globalThis, 'rohdEmbed');
          if (embed != null) {
            final postFn = plat.getProperty(embed, 'postMessage');
            if (postFn != null) {
              plat.callMethod(
                  postFn, 'call', [embed, plat.jsify(message as Map)]);
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
    final jsVal = plat.getProperty(plat.globalThis, '__shiftDown');
    if (jsVal == null) return false;
    // js_util.dartify will convert JS booleans to Dart bool
    try {
      final dartVal = plat.dartify(jsVal);
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
