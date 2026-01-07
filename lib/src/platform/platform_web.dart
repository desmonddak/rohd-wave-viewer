@JS()
library rohd_js_interop_bindings_web;

import 'package:js/js.dart';

// Re-export web-specific platform helpers
export 'embed_web.dart' show signalEmbedReadyImpl, postMessageToHostImpl, isShiftDownFromJsImpl;
export 'js_bindings_web.dart' show jsRequestAnimationFrame, jsRohdForceRepaint;
export 'window_messages_web.dart' show addWindowMessageListener, removeWindowMessageListener;
export 'url_strategy_web.dart' show setUrlStrategySafe;

// Inline @JS bindings used by the web platform so consumers don't need a
// separate `js_interop_bindings.dart` indirection. These symbols are only
// available on web builds due to the conditional export from `platform.dart`.
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
