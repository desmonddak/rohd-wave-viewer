import 'dart:convert';
import 'package:js/js_util.dart' as js_util;
import 'js_interop_bindings.dart' as binds;

typedef WindowMessageCallback = void Function(dynamic data);

// Add a window 'message' event listener on web and forward to the Dart callback.
void addWindowMessageListener(WindowMessageCallback cb) {
  try {
    // Use JS interop binding to register a message handler on window
    try {
      binds.requestAnimationFrame((_) {}); // ensure binding is present
    } catch (_) {}
    // Add a generic listener via JS global window.addEventListener
    final addEvent =
        js_util.getProperty(js_util.globalThis, 'addEventListener');
    if (addEvent != null) {
      js_util.callMethod(js_util.globalThis, 'addEventListener', [
        'message',
        js_util.allowInterop((e) {
          try {
            final data = js_util.getProperty(e, 'data');
            if (data == null) return;
            if (data is String) {
              try {
                final parsed = json.decode(data);
                cb(parsed);
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
    }
  } catch (e) {
    // ignore
  }
}

void removeWindowMessageListener(WindowMessageCallback cb) {
  // No-op: package:web does not provide an easy way to remove the anonymous
  // listener we added above.
}
