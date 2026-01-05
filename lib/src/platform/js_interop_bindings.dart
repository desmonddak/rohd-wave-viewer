@JS()
library rohd_js_interop_bindings;

import 'package:js/js.dart';

// Access global property rohdEmbed (may be null)
@JS('rohdEmbed')
external dynamic get rohdEmbed;

// rohdEmbed may have onMessage(callback) and postMessage(msg)
@JS()
class RohdEmbed {
  external dynamic get onMessage;
  external void postMessage(dynamic msg);
}

// Global function rohdForceRepaint
@JS('rohdForceRepaint')
external void rohdForceRepaint();

// Window.postRohd shim (global property on window)
@JS('postRohd')
external dynamic get postRohd;

// requestAnimationFrame binding
@JS('requestAnimationFrame')
external void requestAnimationFrame(Function callback);
