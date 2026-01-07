import 'dart:convert';
import 'platform.dart' as plat;

typedef WindowMessageCallback = void Function(dynamic data);

// Add a window 'message' event listener on web and forward to the Dart callback.
void addWindowMessageListener(WindowMessageCallback cb) {
  try {
    // Use JS interop binding to register a message handler on window
    try {
      plat.requestAnimationFrame((_) {}); // ensure binding is present
    } catch (_) {}
    // Add a generic listener via JS global window.addEventListener
    final addEvent =
        plat.getProperty(plat.globalThis, 'addEventListener');
    if (addEvent != null) {
      plat.callMethod(plat.globalThis, 'addEventListener', [
        'message',
        plat.allowInterop((e) {
          try {
            final data = plat.getProperty(e, 'data');
            if (data == null) return;
            if (data is String) {
              try {
                final parsed = json.decode(data);
                cb(parsed);
                return;
              } catch (_) {}
            }
            try {
                final dartified = plat.dartify(data);
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
