# WASM WebView Compatibility Patch

This document explains the WebAssembly patching required for the ROHD Wave Viewer VS Code extension to work in VS Code Remote environments (Remote-Containers, Remote-SSH, WSL).

## Problem Summary

The extension fails to load in VS Code Remote webviews with the error:

```
RangeError: WebAssembly.Table.grow(): failed to grow table by 4
```

This error occurs during WASM initialization when `wasm-bindgen` tries to grow the externref table.

## Root Cause

There are two issues at play:

### 1. wasm-bindgen Export Bug

When `wasm-pack` builds the WASM binary, it creates two tables:

| Table Index | Type | Purpose | Size |
|-------------|------|---------|------|
| `table[0]` | funcref | Function references | 313 entries |
| `table[1]` | externref | JavaScript object references | 128 entries |

The generated code exports `__wbindgen_externrefs` which should point to the externref table (`table[1]`), but instead incorrectly points to the funcref table (`table[0]`):

```wat
;; Bug: exports table 0 (funcref) instead of table 1 (externref)
(export "__wbindgen_externrefs" (table 0))
```

### 2. VS Code Remote Webview Sandbox Restriction

VS Code Remote environments (Remote-Containers, Remote-SSH, WSL) run webviews in a more restrictive sandbox than local VS Code. This sandbox **blocks** the `WebAssembly.Table.grow()` operation, even though the underlying Chromium/Electron browser supports the WebAssembly reference-types feature.

The generated JavaScript code calls:
```javascript
const offset = table.grow(4);  // Throws RangeError in Remote webview
```

## Why It Works Locally

On a local VS Code installation (not Remote):
- The webview sandbox is less restrictive
- `Table.grow()` is allowed to execute
- The code works despite the table export bug (the grow operation succeeds on the wrong table type without causing immediate failure)

## The Patch

The build script (`build_extension.sh`) applies a two-part patch:

### Part 1: WASM Binary Patch

Using `wabt` tools (`wasm2wat` and `wat2wasm`), the build script:

1. **Pre-allocates extra table slots**: Changes the externref table from 128 to 132 initial entries
   ```wat
   ;; Before
   (table (;1;) 128 externref)
   
   ;; After
   (table (;1;) 132 externref)
   ```

2. **Fixes the export**: Corrects `__wbindgen_externrefs` to point to `table[1]`
   ```wat
   ;; Before (bug)
   (export "__wbindgen_externrefs" (table 0))
   
   ;; After (fixed)
   (export "__wbindgen_externrefs" (table 1))
   ```

### Part 2: JavaScript Patch

The build script modifies `wellen_bridge.js` to wrap `table.grow()` in a try/catch:

```javascript
// Before (generated code)
const offset = table.grow(4);

// After (patched)
let offset;
try {
    offset = table.grow(4);
} catch (e) {
    console.warn('Table.grow(4) failed, using fallback:', e.message);
    // Use pre-allocated slots at the end of the table (128-131)
    offset = table.length - 4;
}
```

## Environment Comparison

| Environment | `Table.grow()` | Patch Needed? |
|-------------|----------------|---------------|
| Local VS Code (Linux/macOS/Windows) | Allowed | No* |
| Remote-Containers | Blocked | **Yes** |
| Remote-SSH | Blocked | **Yes** |
| WSL Remote | Blocked | **Yes** |
| Codespaces | Blocked | **Yes** |

\* The patch is harmless on local VS Code and ensures consistent behavior across all environments.

## Build Requirements

The patch requires the `wabt` (WebAssembly Binary Toolkit) package:

```bash
# Ubuntu/Debian
sudo apt install wabt

# Fedora/RHEL
sudo dnf install wabt

# macOS (Homebrew)
brew install wabt

# Or build from source: https://github.com/WebAssembly/wabt
```

If `wabt` is not installed, the build script will print a warning and skip the patching step. The extension will still work on local VS Code but will fail in Remote environments.

## Verification

After building, you can verify the patch was applied:

```bash
# Check table definitions and exports
wasm-objdump -x build/web/pkg/wellen_bridge_bg.wasm | grep -E 'table\[|externrefs'

# Expected output:
# - table[0] type=funcref initial=313 max=313
# - table[1] type=externref initial=132        # <-- 132, not 128
# - table[1] -> "__wbindgen_externrefs"        # <-- table[1], not table[0]
```

## Future Considerations

This patch is a workaround. The underlying issues may be resolved in future versions of:

1. **wasm-bindgen**: The table export bug may be fixed upstream
2. **VS Code**: The webview sandbox restrictions may be relaxed for `Table.grow()`
3. **flutter_rust_bridge**: May generate different code that doesn't require table growth at init time

When upgrading `wasm-bindgen` or `flutter_rust_bridge`, test in a Remote environment to verify whether this patch is still needed.

## Related Links

- [WebAssembly Reference Types Proposal](https://github.com/WebAssembly/reference-types)
- [wasm-bindgen Repository](https://github.com/nicedoc/nicedoc.io)
- [VS Code Webview API](https://code.visualstudio.com/api/extension-guides/webview)
- [wabt (WebAssembly Binary Toolkit)](https://github.com/WebAssembly/wabt)
