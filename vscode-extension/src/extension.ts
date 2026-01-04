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

class VcdCustomEditorProvider implements vscode.CustomTextEditorProvider {
  private readonly context: vscode.ExtensionContext;
  constructor(context: vscode.ExtensionContext) { this.context = context; }

  public async resolveCustomTextEditor(document: vscode.TextDocument, webviewPanel: vscode.WebviewPanel, _token: vscode.CancellationToken): Promise<void> {
    webviewPanel.webview.options = { enableScripts: true, localResourceRoots: [vscode.Uri.joinPath(this.context.extensionUri, 'media')] };

    const indexPath = path.join(this.context.extensionPath, 'media', 'flutter_web', 'index.html');
    let html = '<h1>Missing build</h1>';
    try { html = fs.readFileSync(indexPath, { encoding: 'utf8' }); } catch (e) { webviewPanel.webview.html = html; return; }

    webviewPanel.webview.html = transformHtml(html, webviewPanel.webview, this.context);

    // Send file contents to webview after the embedded app signals readiness.
    const sendContents = () => {
      const msg = { type: 'vcdContents', text: document.getText(), uri: document.uri.toString() };
      output.appendLine(`Posting vcdContents to webview for ${document.uri.toString()} (len=${msg.text.length})`);
      webviewPanel.webview.postMessage(msg);
    };

    // Wait for the embedded app to post a 'rohdReady' message, or fallback after timeout.
    let readyReceived = false;
    const readyListener = webviewPanel.webview.onDidReceiveMessage((msg) => {
      if (msg && msg.type === 'rohdReady') {
        output.appendLine('Received rohdReady from webview');
        readyReceived = true;
        sendContents();
      }
      // Forward console messages from the webview shim to the extension output
      if (msg && msg.type === 'console') {
        const line = `[webview:${msg.level}] ${Array.isArray(msg.args) ? msg.args.join(' ') : String(msg.args)}`;
        try { output.appendLine(line); } catch (e) { console.log(line); }
      }
    });

    // Fallback: if no ready within 2s, send contents anyway for debugging
    const readyTimeout = setTimeout(() => {
      if (!readyReceived) {
        console.warn('rohdReady not received from webview; sending vcdContents anyway');
        sendContents();
      }
    }, 2000);

    // Listen for document changes and forward
    const docChange = vscode.workspace.onDidChangeTextDocument(e => { if (e.document === document) sendContents(); });
    webviewPanel.onDidDispose(() => { docChange.dispose(); readyListener.dispose(); clearTimeout(readyTimeout); });

    // Forward messages from webview to host (optional save handling)
    webviewPanel.webview.onDidReceiveMessage(async (msg) => {
      if (msg && msg.type === 'requestSave') {
        const edit = new vscode.WorkspaceEdit();
        edit.replace(document.uri, new vscode.Range(0,0,document.lineCount,0), msg.text);
        await vscode.workspace.applyEdit(edit);
        await document.save();
      }
      // Handle repaint request - echo back to webview to force compositor update
      if (msg && msg.type === 'requestRepaint') {
        // Immediately send a message back to the webview
        // This round-trip through the extension host may wake up the compositor
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

  // Insert shim after opening <body> tag
  html = html.replace(/<body[^>]*>/i, match => match + shimScript);

  return html;
}

export function deactivate() {}
