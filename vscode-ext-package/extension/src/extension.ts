import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

export function activate(context: vscode.ExtensionContext) {
  const disposable = vscode.commands.registerCommand('rohd-wave-viewer.open', () => openStandalone(context));
  context.subscriptions.push(disposable);

  // Register custom editor for .vcd files
  const provider = new VcdCustomEditorProvider(context);
  context.subscriptions.push(vscode.window.registerCustomEditorProvider('rohdWaveViewer.vcd', provider, { supportsMultipleEditorsPerDocument: false }));
}

const output = vscode.window.createOutputChannel('ROHD Wave Viewer');


function openStandalone(context: vscode.ExtensionContext) {
  const panel = vscode.window.createWebviewPanel(
    'rohdWaveViewer',
    'ROHD Wave Viewer',
    vscode.ViewColumn.One,
    {
      enableScripts: true,
      localResourceRoots: [vscode.Uri.joinPath(context.extensionUri, 'media')]
    }
  );

  const mediaPath = path.join(context.extensionPath, 'media');
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
    console.log('Received from webview:', msg);
    if (msg && msg.command === 'ping') {
      panel.webview.postMessage({ reply: 'pong' });
    }
  });
}

class VcdCustomEditorProvider implements vscode.CustomTextEditorProvider {
  private readonly context: vscode.ExtensionContext;
  constructor(context: vscode.ExtensionContext) { this.context = context; }

  public async resolveCustomTextEditor(document: vscode.TextDocument, webviewPanel: vscode.WebviewPanel, _token: vscode.CancellationToken): Promise<void> {
    // Allow the webview to load extension media and the document's folder so it can fetch the file URI directly.
    const docFolder = vscode.Uri.joinPath(document.uri, '..');
    webviewPanel.webview.options = { enableScripts: true, localResourceRoots: [vscode.Uri.joinPath(this.context.extensionUri, 'media'), docFolder] };

    const indexPath = path.join(this.context.extensionPath, 'media', 'index.html');
    let html = '<h1>Missing build</h1>';
    try { html = fs.readFileSync(indexPath, { encoding: 'utf8' }); } catch (e) { webviewPanel.webview.html = html; return; }

    webviewPanel.webview.html = transformHtml(html, webviewPanel.webview, this.context);

    // Send either inline contents (for .vcd) or a webview URI (for other formats)
    const sendContents = () => {
      const pathLower = document.uri.path.toLowerCase();
      if (pathLower.endsWith('.vcd')) {
        const msg = { type: 'vcdContents', text: document.getText(), uri: document.uri.toString() };
        console.log('Posting vcdContents to webview for', document.uri.toString());
        webviewPanel.webview.postMessage(msg);
      } else {
        const vcdUri = webviewPanel.webview.asWebviewUri(document.uri);
        console.log('Posting vcdUri to webview for', document.uri.toString());
        webviewPanel.webview.postMessage({ type: 'vcdUri', uri: vcdUri.toString(), originalUri: document.uri.toString() });
      }
    };

    // Wait for the embedded app to post a 'rohdReady' message, or fallback after timeout.
    let readyReceived = false;
    const readyListener = webviewPanel.webview.onDidReceiveMessage((msg) => {
      if (msg && msg.type === 'rohdReady') {
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

    // Forward messages from webview to host (optional save handling). Accepts either an inline 'text' or a 'uri' to re-open.
    webviewPanel.webview.onDidReceiveMessage(async (msg) => {
      if (!msg) return;
      if (msg.type === 'requestSave') {
        if (typeof msg.text === 'string') {
          const edit = new vscode.WorkspaceEdit();
          edit.replace(document.uri, new vscode.Range(0,0,document.lineCount,0), msg.text);
          await vscode.workspace.applyEdit(edit);
          await document.save();
        } else if (typeof msg.uri === 'string') {
          // If webview provides a URI with updated contents, read and write it back to the original document.
          try {
            const updated = await vscode.workspace.fs.readFile(vscode.Uri.parse(msg.uri));
            const text = Buffer.from(updated).toString('utf8');
            const edit = new vscode.WorkspaceEdit();
            edit.replace(document.uri, new vscode.Range(0,0,document.lineCount,0), text);
            await vscode.workspace.applyEdit(edit);
            await document.save();
          } catch (e) {
            console.warn('Failed to read save URI from webview', e);
          }
        }
      }
    });

    // Initial send
    sendContents();
  }
}

function transformHtml(html: string, webview: vscode.Webview, context: vscode.ExtensionContext) {
  const cspSource = webview.cspSource;
  // Inject CSP meta if missing
  if (!/Content-Security-Policy/i.test(html)) {
    const meta = `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-eval' 'unsafe-inline' ${cspSource}; style-src 'unsafe-inline' ${cspSource}; img-src ${cspSource} data:;">`;
    html = html.replace(/<head[^>]*>/i, match => match + meta);
  }

  // Replace absolute / asset paths with webview URIs
  const mediaUri = vscode.Uri.joinPath(context.extensionUri, 'media');
  html = html.replace(/src="\/([^\"]+)"/g, (m, p1) => {
    const uri = webview.asWebviewUri(vscode.Uri.joinPath(mediaUri, p1));
    return `src="${uri.toString()}"`;
  });
  html = html.replace(/href="\/([^\"]+)"/g, (m, p1) => {
    const uri = webview.asWebviewUri(vscode.Uri.joinPath(mediaUri, p1));
    return `href="${uri.toString()}"`;
  });

  // Also replace references without leading slash (just in case)
  html = html.replace(/src="([^\.][^\"]+)"/g, (m, p1) => {
    if (p1.startsWith('http') || p1.startsWith('data:') || p1.startsWith('blob:')) return m;
    const uri = webview.asWebviewUri(vscode.Uri.joinPath(mediaUri, p1));
    return `src="${uri.toString()}"`;
  });

  // Inject embed shim for communication between Flutter and extension (same shim used in the other extension copy)
  const shimScript = `
<script>
  const vscode = (typeof acquireVsCodeApi === 'function') ? acquireVsCodeApi() : { postMessage: () => {} };
  window.postRohd = function(msg) { try { vscode.postMessage(msg); } catch (e) {} };
  window.rohdEmbed = {
    onMessage: function(callback) { window.__rohdMessageCallback = callback; },
    postMessage: function(msg) { try { vscode.postMessage(msg); } catch (e) {} }
  };
  ['log','warn','error','info','debug'].forEach(level => {
    const orig = console[level];
    console[level] = function(...args) { orig.apply(console, args); try { vscode.postMessage({ type: 'console', level: level, args: args.map(a => String(a)) }); } catch(e) {} };
  });
  window.addEventListener('message', (e) => {
    const msg = e.data;
    if (window.__rohdMessageCallback) window.__rohdMessageCallback(msg);
    if (msg && msg.type === 'repaintAck') {
      document.body.style.opacity = '0.9999';
      requestAnimationFrame(function(){ document.body.style.opacity = '1'; });
    }
  });
  window.__rohdEmbedReady = function(info) { try { vscode.postMessage({ type: 'rohdReady', info: info }); } catch(e) {} };
</script>`;

  const fetchHandler = `
<script>
  // Handle vcdUri by fetching the file and forwarding contents to the embed
  window.addEventListener('message', (e) => {
    const msg = e.data;
    if (msg && msg.type === 'vcdUri') {
      (async function() {
        try {
          const res = await fetch(msg.uri);
            const text = await res.text();
            if (window.__rohdMessageCallback) window.__rohdMessageCallback({ type: 'vcdContents', text: text, uri: msg.originalUri });
            try { window.postMessage({ type: 'vcdContents', text: text, uri: msg.originalUri }, '*'); } catch(e) { console.error('postMessage vcdContents failed', e); }
        } catch (err) {
          console.error('Failed to fetch vcdUri', err);
          try { vscode.postMessage({ type: 'console', level: 'error', args: ['Failed to fetch vcdUri', String(err)] }); } catch(e) {}
        }
      })();
    }
  });
</script>`;

  html = html.replace(/<body[^>]*>/i, match => match + shimScript + fetchHandler);

  return html;
}

export function deactivate() {}
