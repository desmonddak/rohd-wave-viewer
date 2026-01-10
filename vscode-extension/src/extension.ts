import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

const output = vscode.window.createOutputChannel('ROHD Wave Viewer');

export function activate(context: vscode.ExtensionContext) {
  output.appendLine('ROHD Wave Viewer: activating extension');
  const disposable = vscode.commands.registerCommand('rohd-wave-viewer.open', () => {
    output.appendLine('ROHD Wave Viewer: open command invoked');
    openStandalone(context);
  });
  context.subscriptions.push(disposable);

  // Register custom editor for .vcd files
  const provider = new VcdCustomEditorProvider(context);
  context.subscriptions.push(vscode.window.registerCustomEditorProvider('rohdWaveViewer.vcd', provider, { 
    supportsMultipleEditorsPerDocument: false,
    webviewOptions: {
      retainContextWhenHidden: true  // Keep WebView alive when hidden to prevent rendering issues
    }
  }));
}

function openStandalone(context: vscode.ExtensionContext) {
  output.appendLine('ROHD Wave Viewer: opening standalone webview');
  const panel = vscode.window.createWebviewPanel(
    'rohdWaveViewer',
    'ROHD Wave Viewer',
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      localResourceRoots: [vscode.Uri.joinPath(context.extensionUri, 'media')],
      retainContextWhenHidden: true  // Keep WebView alive when hidden to prevent rendering issues
    }
  );

  const mediaPath = path.join(context.extensionPath, 'media', 'flutter_web');
  const indexPath = path.join(mediaPath, 'index.html');
  let html = '<h1>Missing build</h1>';
  try {
    html = fs.readFileSync(indexPath, { encoding: 'utf8' });
  } catch (e) {
    panel.webview.html = html;
    return;
  }

  const transformed = transformHtml(html, panel.webview, context);
  panel.webview.html = transformed;

  panel.webview.onDidReceiveMessage(msg => {
    output.appendLine(`webview -> extension message: ${JSON.stringify(msg)}`);
    if (msg && msg.command === 'ping') {
      panel.webview.postMessage({ reply: 'pong' });
    }
    // Handle repaint request - echo back to webview to force compositor update
    if (msg && msg.type === 'requestRepaint') {
      panel.webview.postMessage({ type: 'repaintAck', timestamp: Date.now() });
    }
  });
}

class VcdCustomEditorProvider implements vscode.CustomReadonlyEditorProvider {
  private readonly context: vscode.ExtensionContext;
  constructor(context: vscode.ExtensionContext) { this.context = context; }

  public async openCustomDocument(
    uri: vscode.Uri,
    _openContext: vscode.CustomDocumentOpenContext,
    _token: vscode.CancellationToken
  ): Promise<vscode.CustomDocument> {
    return { uri, dispose: () => {} };
  }

  public async resolveCustomEditor(document: vscode.CustomDocument, webviewPanel: vscode.WebviewPanel, _token: vscode.CancellationToken): Promise<void> {
    // Allow the webview to load extension media and the document's folder so it can fetch the file URI directly.
    const docUri = document.uri as vscode.Uri;
    const docFolder = vscode.Uri.joinPath(docUri, '..');
    webviewPanel.webview.options = { enableScripts: true, localResourceRoots: [vscode.Uri.joinPath(this.context.extensionUri, 'media'), docFolder] };

    const indexPath = path.join(this.context.extensionPath, 'media', 'flutter_web', 'index.html');
    let html = '<h1>Missing build</h1>';
    try { html = fs.readFileSync(indexPath, { encoding: 'utf8' }); } catch (e) { webviewPanel.webview.html = html; return; }

    webviewPanel.webview.html = transformHtml(html, webviewPanel.webview, this.context);

    // Send either inline contents (for .vcd) or a webview URI (for other formats)
    const sendContents = async () => {
      const pathLower = docUri.path.toLowerCase();
      if (pathLower.endsWith('.vcd')) {
        try {
          const bytes = await vscode.workspace.fs.readFile(docUri);
          const text = Buffer.from(bytes).toString('utf8');
          const msg = { type: 'vcdContents', text: text, uri: docUri.toString() };
          output.appendLine(`Posting vcdContents to webview for ${docUri.toString()} (len=${msg.text.length})`);
          webviewPanel.webview.postMessage(msg);
        } catch (e) {
          output.appendLine(`Failed to read vcd as bytes: ${e}`);
        }
      } else {
        const vcdUri = webviewPanel.webview.asWebviewUri(docUri);
        output.appendLine(`Posting vcdUri to webview for ${docUri.toString()}`);
        webviewPanel.webview.postMessage({ type: 'vcdUri', uri: vcdUri.toString(), originalUri: docUri.toString() });
      }
    };

    // Wait for the embedded app to post a 'rohdReady' message, or fallback after timeout.
    let readyReceived = false;
    const readyListener = webviewPanel.webview.onDidReceiveMessage((msg) => {
      if (msg && msg.type === 'rohdReady') {
        output.appendLine('Received rohdReady from webview');
        readyReceived = true;
        const wasmOk = msg.info && msg.info.wasm === true;
        if (!wasmOk) {
          output.appendLine('Webview reported WASM initialization FAILED; not sending VCD bytes.');
        } else {
          sendContents();
        }
      }
      if (msg && msg.type === 'console') {
        const line = `[webview:${msg.level}] ${Array.isArray(msg.args) ? msg.args.join(' ') : String(msg.args)}`;
        try { output.appendLine(line); } catch (e) { console.log(line); }
      }
    });

    const readyTimeout = setTimeout(() => {
      if (!readyReceived) {
        console.warn('rohdReady not received from webview; sending vcdContents anyway');
        sendContents();
      }
    }, 2000);

    // Basic file watcher: re-send contents when file changes
    const fsWatcher = vscode.workspace.createFileSystemWatcher(docUri.fsPath);
    const onChange = () => sendContents();
    fsWatcher.onDidChange(onChange);
    fsWatcher.onDidCreate(onChange);
    fsWatcher.onDidDelete(onChange);
    webviewPanel.onDidDispose(() => { fsWatcher.dispose(); readyListener.dispose(); clearTimeout(readyTimeout); });

    // Forward messages from webview to host (optional save handling)
    webviewPanel.webview.onDidReceiveMessage(async (msg) => {
      if (msg && msg.type === 'requestSave') {
        if (typeof msg.text === 'string') {
          // Overwrite via workspace edit (best-effort)
          const edit = new vscode.WorkspaceEdit();
          const uri = docUri;
          try {
            const bytes = Buffer.from(msg.text, 'utf8');
            await vscode.workspace.fs.writeFile(uri, bytes);
          } catch (e) {
            output.appendLine(`Failed to write file: ${e}`);
          }
        } else if (typeof msg.uri === 'string') {
          try {
            const updated = await vscode.workspace.fs.readFile(vscode.Uri.parse(msg.uri));
            const text = Buffer.from(updated).toString('utf8');
            // best-effort write
            await vscode.workspace.fs.writeFile(docUri, Buffer.from(text, 'utf8'));
          } catch (e) {
            output.appendLine(`Failed to read save URI from webview: ${e}`);
          }
        }
      }
      if (msg && msg.type === 'requestRepaint') {
        webviewPanel.webview.postMessage({ type: 'repaintAck', timestamp: Date.now() });
      }
    });

    // Initial send
    sendContents();
  }
}

function transformHtml(html: string, webview: vscode.Webview, context: vscode.ExtensionContext) {
  const cspSource = webview.cspSource;
  // Inject CSP meta if missing - includes wasm-unsafe-eval for WASM support and gstatic.com for CanvasKit
  if (!/Content-Security-Policy/i.test(html)) {
    const meta = `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'wasm-unsafe-eval' 'unsafe-eval' 'unsafe-inline' ${cspSource} https://www.gstatic.com; style-src 'unsafe-inline' ${cspSource}; img-src ${cspSource} data: blob:; connect-src ${cspSource} https://www.gstatic.com https:; font-src ${cspSource} data:; worker-src ${cspSource} blob:;">`;
    html = html.replace(/<head[^>]*>/i, match => match + meta);
  }

  // The Flutter web build is in media/flutter_web/
  const flutterWebUri = vscode.Uri.joinPath(context.extensionUri, 'media', 'flutter_web');

  // Replace base href with the webview URI for flutter_web folder
  const baseUri = webview.asWebviewUri(flutterWebUri).toString() + '/';
  html = html.replace(/<base\s+href="[^"]*"/gi, `<base href="${baseUri}"`);

  // Replace absolute / asset paths with webview URIs
  html = html.replace(/src="\/([^\"]+)"/g, (m, p1) => {
    const uri = webview.asWebviewUri(vscode.Uri.joinPath(flutterWebUri, p1));
    return `src="${uri.toString()}"`;
  });
  html = html.replace(/href="\/([^\"]+)"/g, (m, p1) => {
    const uri = webview.asWebviewUri(vscode.Uri.joinPath(flutterWebUri, p1));
    return `href="${uri.toString()}"`;
  });

  // Replace relative paths (not starting with http/data/blob) with webview URIs
  html = html.replace(/src="([^\.\/][^\"]*\.js)"/g, (m, p1) => {
    if (p1.startsWith('http') || p1.startsWith('data:') || p1.startsWith('blob:')) return m;
    const uri = webview.asWebviewUri(vscode.Uri.joinPath(flutterWebUri, p1));
    return `src="${uri.toString()}"`;
  });

  // Inject embed shim for communication between Flutter and extension
  const shimScript = `
<script>
  // Shim for Flutter web <-> VS Code extension communication
  const vscode = acquireVsCodeApi();
  
  // Global for Flutter to post messages back
  window.postRohd = function(msg) { vscode.postMessage(msg); };
  
  // Setup message receiver for Flutter
  window.rohdEmbed = {
    onMessage: function(callback) {
      window.__rohdMessageCallback = callback;
    },
    postMessage: function(msg) { vscode.postMessage(msg); }
  };
  
  // Forward console messages to extension for debugging
  ['log','warn','error','info','debug'].forEach(level => {
    const orig = console[level];
    console[level] = function(...args) {
      orig.apply(console, args);
      vscode.postMessage({ type: 'console', level: level, args: args.map(a => String(a)) });
    };
  });
  
  // Listen for messages from extension
  window.addEventListener('message', (e) => {
    const msg = e.data;
    console.log('[embedShim] Received message:', msg?.type);
    
    // Handle repaintAck from extension - this round-trip should wake up compositor
    if (msg && msg.type === 'repaintAck') {
      console.log('[embedShim] Got repaintAck, forcing DOM update');
      // Do a visible DOM change to try to wake up the compositor
      document.body.style.opacity = '0.9999';
      requestAnimationFrame(function() {
        document.body.style.opacity = '1';
        // Also dispatch a pointer event to simulate mouse movement
        try {
          var canvas = document.querySelector('canvas');
          if (canvas) {
            var rect = canvas.getBoundingClientRect();
            var evt = new PointerEvent('pointermove', {
              bubbles: true,
              clientX: rect.left + rect.width / 2,
              clientY: rect.top + rect.height / 2,
              pointerType: 'mouse'
            });
            canvas.dispatchEvent(evt);
          }
        } catch(e) {}
      });
    }
    
    if (window.__rohdMessageCallback) {
      window.__rohdMessageCallback(msg);
    }
  });
  
  // Notify when Flutter app signals ready
  window.__rohdEmbedReady = function(info) {
    console.log('[embedShim] Flutter app ready:', JSON.stringify(info));
    vscode.postMessage({ type: 'rohdReady', info: info });
  };
</script>`;

  // Fetch handler: when extension posts a webview URI (vcdUri), fetch it
  // and forward either text (vcdContents) or bytes (vcdBytes) to the embed.
  const fetchHandler = `
<script>
  window.addEventListener('message', (e) => {
    const msg = e.data;
    if (msg && msg.type === 'vcdUri') {
      (async function() {
        try {
          const res = await fetch(msg.uri);
          const contentType = res.headers.get('content-type') || '';
          if (contentType.indexOf('text') !== -1 || msg.originalUri.toLowerCase().endsWith('.vcd')) {
            const text = await res.text();
            if (window.__rohdMessageCallback) window.__rohdMessageCallback({ type: 'vcdContents', text: text, uri: msg.originalUri });
            try { window.postMessage({ type: 'vcdContents', text: text, uri: msg.originalUri }, '*'); } catch(e) { console.error('postMessage vcdContents failed', e); }
          } else {
            const buf = await res.arrayBuffer();
            const uint8 = new Uint8Array(buf);
            try { window.__rohdMessageCallback({ type: 'vcdBytes', bytes: uint8, uri: msg.originalUri }); } catch(e) {}
            try { window.postMessage({ type: 'vcdBytes', bytes: uint8, uri: msg.originalUri }, '*'); } catch(e) { console.error('postMessage vcdBytes failed', e); }
          }
        } catch (err) {
          console.error('Failed to fetch vcdUri', err);
          try { vscode.postMessage({ type: 'console', level: 'error', args: ['Failed to fetch vcdUri', String(err)] }); } catch(e) {}
        }
      })();
    }
  });
</script>`;

  // Insert shim and fetch handler after opening <body> tag
  html = html.replace(/<body[^>]*>/i, match => match + shimScript + fetchHandler);

  return html;
}

export function deactivate() {}
