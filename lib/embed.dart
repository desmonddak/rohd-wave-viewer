// Tiny helper to interact with the embed shim when running as Flutter web.
import 'dart:js_interop';

@JS('console.log')
external void _consoleLog(JSAny? message, [JSAny? arg]);

@JS('window.__rohdEmbedReady')
external JSFunction? get _rohdEmbedReady;

@JS('window.postRohd')
external JSFunction? get _postRohd;

@JS('window.rohdEmbed.postMessage')
external JSFunction? get _rohdEmbedPostMessage;

@JS('window.__shiftDown')
external JSAny? get _shiftDown;

void signalEmbedReady([Map<String, dynamic>? info]) {
  try {
    // Ensure we mark that this load was (re)loaded inside the GUI
    final payload = Map<String, dynamic>.from(info ?? {'initialized': true});
    payload['reloaded_in_gui'] = true;

    // Log on the page so embed shims can surface this in host logs
    try {
      _consoleLog('[embed] signalEmbedReady called'.toJS, payload.jsify());
    } catch (_) {}

    final callback = _rohdEmbedReady;
    if (callback != null) {
      callback.callAsFunction(null, payload.jsify());
    }
  } catch (e) {
    // ignore if not available (native apps)
  }
}

void postMessageToHost(Object message) {
  try {
    final post = _postRohd;
    if (post != null) {
      post.callAsFunction(null, (message as Map).jsify());
      return;
    }
    final postFn = _rohdEmbedPostMessage;
    if (postFn != null) {
      postFn.callAsFunction(null, (message as Map).jsify());
    }
  } catch (e) {
    // no-op
  }
}

/// Returns true if the page-level JS tracker thinks Shift is down.
bool isShiftDownFromJs() {
  try {
    final jsVal = _shiftDown;
    if (jsVal == null) return false;
    if (jsVal.isA<JSBoolean>()) {
      return (jsVal as JSBoolean).toDart;
    }
    // If it's a JS value that isn't a direct Dart bool, coerce via toString
    return jsVal.toString().toLowerCase() == 'true';
  } catch (e) {
    return false;
  }
}
