ROHD Wave Viewer VS Code Extension

This folder contains a minimal VS Code extension that hosts the Flutter web build (from `build/web`) inside a Webview.

Quick start:

1. Build the Flutter web app:

```bash
flutter build web
```

2. Copy the build into the extension media folder:

```bash
cd vscode-extension
./scripts/copy_web_build.sh
```

3. Install dependencies and compile the extension:

```bash
npm install
npm run compile
```

4. Run the extension in the Extension Development Host using the provided launch configuration.

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

This extension registers a custom editor for `*.vcd` files. When you open a `.vcd` file, the extension:

- Creates a Webview and loads the embedded Flutter web build.
- Posts the file contents to the webview via `postMessage({ type: 'vcdContents', text, uri })`.
- Listens for `requestSave` messages from the webview to write back changes to the file.

The embedded app should listen for `vcdContents` messages and respond with messages as needed. Example:

```js
window.addEventListener('message', (ev) => {
	const msg = ev.data;
	if (msg && msg.type === 'vcdContents') {
		// Load VCD text in the viewer
		console.log('VCD content for', msg.uri, msg.text.slice(0,200));
	}
});
```


