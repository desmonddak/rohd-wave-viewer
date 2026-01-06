// This file conditionally exports the real JS interop implementation when
// `dart:js`/`package:js` is available, otherwise falls back to the no-JS shim.
export 'js_interop_bindings_nojs.dart'
    if (dart.library.js) 'js_interop_bindings_js.dart';
