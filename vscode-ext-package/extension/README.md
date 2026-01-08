Short description: Packaging/template assets for the VS Code extension

This folder holds the packaging and template assets used when building or packaging the extension.

- `vscode-ext-package/extension/` contains static files (README, media, manifest, icons) that are copied into the final extension package.
- The TypeScript source and compilation live under `vscode-extension/`.

Packaging workflow summary:

1. Compile the TypeScript in `vscode-extension`:

   npm --prefix vscode-extension run compile

2. The packaging step copies this folder's contents (assets and manifest) plus the compiled JS from `vscode-extension/out/` into the extension target directory. See `scripts/build_extension.sh` and `scripts/build_vsix.tcsh`.

Notes:

- Keep static assets here. The build scripts expect to find packaging assets in this folder.
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
- Listens for `requestSave` messages from the webview to write back changes to the original file.

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
