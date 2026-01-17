Short description: VS Code extension source and build output

This folder is the **TypeScript source** and development workspace for the VS Code extension used by rohd-wave-viewer.

- `vscode-extension/` contains the TypeScript sources and development config (launch.json).
- `vscode-extension/out/` is the compiled JavaScript output produced by `npm run compile`.

Development workflow summary:

1. From the repo root, compile the extension JavaScript:

   npm --prefix vscode-extension run compile

2. The build/packaging step copies packaging/template assets from `vscode-ext-package/extension/` and the compiled `vscode-extension/out/` to the target extension directory (see `make extension` target in the Makefile).

Notes:

- Keep TypeScript source in this folder. Do not commit compiled artifacts unless explicitly desired by your workflow.

ROHD Wave Viewer VS Code Extension

This folder contains a minimal VS Code extension that hosts the Flutter web build (from `build/web`) inside a Webview.

Quick start:

1. Build the Flutter web app:

```bash
flutter build web
```

1. Copy the build into the extension media folder:

```bash
cd vscode-extension
./scripts/copy_web_build.sh
```

1. Install dependencies and compile the extension:

```bash
npm install
npm run compile
```

1. Run the extension in the Extension Development Host using the provided launch configuration.

Embedding API
-------------

The extension ships a small JavaScript shim `embed-shim.js` that exposes a simple API on `window.rohdEmbed`.

- `rohdEmbed.postMessage(msg)` sends a message to the host (VS Code extension or parent frame).
- `rohdEmbed.onMessage(cb)` registers a callback for messages from the host. Returns an unsubscribe function.
- `rohdEmbed.ready` is a promise that resolves when the embedded app calls `window.__rohdEmbedReady(info)` (call this from your Flutter JS interop when the app is initialized).

To signal readiness from Flutter, use a JS interop call such as:

```js
if (window.__rohdEmbedReady) window.__rohdEmbedReady({ initialized: true });
```

Then the host extension can send messages to the app and receive responses.

.vcd Custom Editor
------------------

This extension registers a custom editor for waveform files (e.g., `*.vcd`, `*.ghw`, `*.fst`). When you open a supported file, the extension:

- Creates a Webview and loads the embedded Flutter web build.
- Posts a webview-accessible URI to the webview via `postMessage({ type: 'vcdUri', uri, originalUri })`.
- Listens for `requestSave` messages from the webview to write back changes to the file.

The embedded app should listen for `vcdUri` messages and fetch the provided URI. Example (embedded JS):

```js
window.addEventListener('message', (ev) => {
  const msg = ev.data;
  if (msg && msg.type === 'vcdUri') {
    fetch(msg.uri).then(r => r.text()).then(text => {
      // Load VCD text in the viewer
      console.log('VCD content for', msg.originalUri, text.slice(0,200));
      // Forward to your app's message handler if needed
      if (window.__rohdMessageCallback) window.__rohdMessageCallback({ type: 'vcdContents', text, uri: msg.originalUri });
    });
  }
});
```
