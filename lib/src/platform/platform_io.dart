// Re-export IO/native platform helpers and include the aggregated no-JS shim
export 'embed_io.dart' show signalEmbedReadyImpl, postMessageToHostImpl, isShiftDownFromJsImpl;
export 'js_bindings_io.dart' show jsRequestAnimationFrame, jsRohdForceRepaint;
export 'window_messages_io.dart' show addWindowMessageListener, removeWindowMessageListener;
export 'url_strategy_io.dart' show setUrlStrategySafe;

// ---------------------------------------------------------------------------
// Aggregated no-JS shim (inlined from platform_nojs.dart)
// This provides a minimal `js_util`-like surface and JS externals stubs
// for builds that don't support `dart:js` / `package:js` (e.g. dart2wasm).

final _global = <String, dynamic>{};

dynamic get globalThis => _global;

dynamic getProperty(dynamic target, String prop) {
	try {
		if (target is Map) return target[prop];
		return null;
	} catch (_) {
		return null;
	}
}

void setProperty(dynamic target, String prop, dynamic value) {
	try {
		if (target is Map) target[prop] = value;
	} catch (_) {}
}

dynamic callMethod(dynamic target, String method, List args) {
	try {
		final fn = getProperty(target, method);
		if (fn is Function) return Function.apply(fn, args);
	} catch (_) {}
	return null;
}

dynamic allowInterop(Function f) => f;

dynamic dartify(dynamic o) => o;

dynamic jsify(dynamic o) => o;

// ---------------------- JS externals no-op stubs -------------------------

dynamic get rohdEmbed => null;

class RohdEmbed {
	dynamic get onMessage => null;
	void postMessage(dynamic msg) {}
}

void rohdForceRepaint() {}

dynamic get postRohd => null;

void requestAnimationFrame(Function callback) {
	Future.microtask(() => callback(0));
}

