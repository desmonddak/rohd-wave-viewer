// Tiny helper to interact with the embed shim when running as Flutter web.
import 'dart:js' as js;

void signalEmbedReady([Map<String, dynamic>? info]) {
  try {
    final callback = js.context['__rohdEmbedReady'];
    if (callback != null && callback is js.JsFunction) {
      callback.apply([js.JsObject.jsify(info ?? {'initialized': true})]);
    }
  } catch (e) {
    // ignore if not available (native apps)
  }
}

void postMessageToHost(Object message) {
  try {
    final post = js.context['postRohd'];
    if (post != null && post is js.JsFunction) {
      post.apply([js.JsObject.jsify(message)]);
      return;
    }
    final api = js.context['rohdEmbed'];
    if (api != null) {
      final postFn = api['postMessage'];
      if (postFn != null && postFn is js.JsFunction) postFn.apply([js.JsObject.jsify(message)]);
    }
  } catch (e) {
    // no-op
  }
}
