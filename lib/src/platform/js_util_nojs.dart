// Minimal shim replicating the small `js_util` surface used by this repo
// when compiling to Wasm or when `package:js`/`dart:js` are unavailable.

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
