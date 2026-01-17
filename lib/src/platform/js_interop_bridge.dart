// Copyright (C) 2026 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// js_interop_bridge.dart
// Modernized JS interop using package:web instead of deprecated package:js.
// Centralizes all JS interop imports and provides clean helpers.
//
// 2026 January
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

library js_interop_bridge;

import 'dart:js_interop';
import 'dart:convert' as convert;
import 'package:web/web.dart' as web;

// ============================================================================
// Global access helpers
// ============================================================================

/// Get the JavaScript global object.
dynamic getGlobalThis() => web.window;

/// Get a property from the global object.
dynamic getGlobalProperty(String name) {
  final prop = _getJSProperty(web.window, name);
  return _convertFromJS(prop);
}

/// Call a method on the global object.
dynamic callGlobalMethod(String methodName, List<dynamic> args) =>
    callMethod(web.window, methodName, args);

/// Add an event listener to the window/global.
void addGlobalEventListener(String eventName, Function handler) {
  web.window.addEventListener(
    eventName,
    (web.Event event) {
      handler(event);
    }.toJS as web.EventListener,
  );
}

// ============================================================================
// Property and method access helpers
// ============================================================================

/// Get a property from a JavaScript object.
dynamic getProperty(dynamic obj, dynamic prop) {
  final jsValue = _getJSProperty(obj, prop);
  return _convertFromJS(jsValue);
}

/// Internal: Get raw JS property without converting.
JSAny? _getJSProperty(dynamic obj, dynamic prop) {
  // Use extension method from web package to access object properties
  final jsObj = obj as JSObject;
  final propKey = prop is String ? prop : prop.toString();
  // Access via function call rather than bracket notation
  return _callJSProperty(jsObj, propKey);
}

/// Call a property getter on a JS object using dynamic access.
JSAny? _callJSProperty(JSObject obj, String key) {
  // Use callMethod to dynamically get property
  final method = obj as dynamic;
  return method[key];
}

/// Call a method on a JavaScript object.
dynamic callMethod(dynamic obj, String methodName, List<dynamic> args) {
  final jsObj = obj as JSObject;
  final method = _callJSProperty(jsObj, methodName);
  
  if (method == null) return null;
  
  // Cast to JSFunction and call
  final fn = method as JSFunction;
  if (args.isEmpty) {
    return fn.callAsFunction(jsObj);
  } else {
    // Convert args to JS values
    final jsArgs = args.map((arg) => jsify(arg)).toList();
    return _callJSFunctionWithArgs(fn, jsObj, jsArgs);
  }
}

/// Call a JS function with a list of arguments.
dynamic _callJSFunctionWithArgs(JSFunction fn, JSObject context, List<JSAny?> args) {
  // Use switch or conditionals to handle different arg counts
  switch (args.length) {
    case 0:
      return fn.callAsFunction(context);
    case 1:
      return fn.callAsFunction(context, args[0]);
    case 2:
      return fn.callAsFunction(context, args[0], args[1]);
    case 3:
      return fn.callAsFunction(context, args[0], args[1], args[2]);
    case 4:
      return fn.callAsFunction(context, args[0], args[1], args[2], args[3]);
    default:
      // For more args, call with first available args
      // callAsFunction accepts up to 4 additional args beyond context
      return fn.callAsFunction(context, args[0]);
  }
}

/// Convert a JavaScript Promise to a Dart Future.
Future<T> promiseToFuture<T extends JSAny?>(JSPromise<T> promise) {
  return promise.toDart;
}

// ============================================================================
// Conversion utilities (bridging package:web and dart:js_interop)
// ============================================================================

/// Convert Dart values to JavaScript values.
JSAny? jsify(dynamic value) {
  if (value is JSAny) return value;
  if (value == null) return null;
  if (value is String) return value.toJS;
  if (value is int) return value.toJS;
  if (value is double) return value.toJS;
  if (value is bool) return value.toJS;
  if (value is List) {
    final arr = <JSAny?>[];
    for (final item in value) {
      arr.add(jsify(item));
    }
    return arr.toJS;
  }
  if (value is Map) {
    final obj = <String, JSAny?>{};
    for (final entry in value.entries) {
      obj[entry.key.toString()] = jsify(entry.value);
    }
    return obj.jsify();
  }
  return value as JSAny?;
}

/// Convert JavaScript values to Dart values.
dynamic dartify(JSAny? value) {
  return _convertFromJS(value);
}

/// Internal: Convert JS values to Dart.
dynamic _convertFromJS(JSAny? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is int) return value;
  if (value is double) return value;
  if (value is bool) return value;
  // For objects and arrays, try to convert them
  if (value is JSObject) {
    try {
      // Try to parse as JSON string if possible
      return convert.jsonDecode(convert.jsonEncode(value));
    } catch (_) {
      // Return the JS object as-is if conversion fails
      return value;
    }
  }
  return value;
}

/// Wrap a Dart function to be callable from JavaScript.
/// In dart:js_interop, functions are automatically compatible, so this is a pass-through.
Function allowInterop(Function f) {
  return f;
}

// ============================================================================
// Custom JS bindings (via package:web and dart:js_interop)
// ============================================================================

/// Get the ROHD embed object from the global context.
dynamic get rohdEmbed => getGlobalProperty('rohdEmbed');

/// Force repaint in ROHD.
void rohdForceRepaint() {
  final fn = getGlobalProperty('rohdForceRepaint');
  if (fn != null) {
    (fn as JSFunction).callAsFunction();
  }
}

/// Get the postRohd function from the global context.
dynamic get postRohd => getGlobalProperty('postRohd');

/// Request an animation frame callback.
void requestAnimationFrame(Function callback) {
  final fn = getGlobalProperty('requestAnimationFrame');
  if (fn != null) {
    (fn as JSFunction).callAsFunction(web.window, (callback as dynamic).toJS);
  }
}
