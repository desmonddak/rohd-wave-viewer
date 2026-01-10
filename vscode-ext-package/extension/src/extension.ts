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
    const docUri = document.uri as vscode.Uri;
    const docFolder = vscode.Uri.joinPath(docUri, '..');
    webviewPanel.webview.options = { enableScripts: true, localResourceRoots: [vscode.Uri.joinPath(this.context.extensionUri, 'media'), docFolder] };

    const indexPath = path.join(this.context.extensionPath, 'media', 'index.html');
    let html = '<h1>Missing build</h1>';
    try { html = fs.readFileSync(indexPath, { encoding: 'utf8' }); } catch (e) { webviewPanel.webview.html = html; return; }

    webviewPanel.webview.html = transformHtml(html, webviewPanel.webview, this.context);

    const sendContents = async () => {
      const pathLower = docUri.path.toLowerCase();
      if (pathLower.endsWith('.vcd')) {
        try {
          const bytes = await vscode.workspace.fs.readFile(docUri);
          const text = Buffer.from(bytes).toString('utf8');
          const msg = { type: 'vcdContents', text: text, uri: docUri.toString() };
          console.log('Posting vcdContents to webview for', docUri.toString());
          webviewPanel.webview.postMessage(msg);
        } catch (e) {
          console.warn('Failed to read vcd as bytes', e);
        }
      } else {
        const vcdUri = webviewPanel.webview.asWebviewUri(docUri);
        console.log('Posting vcdUri to webview for', docUri.toString());
        webviewPanel.webview.postMessage({ type: 'vcdUri', uri: vcdUri.toString(), originalUri: docUri.toString() });
      }
    };

    let readyReceived = false;
    const readyListener = webviewPanel.webview.onDidReceiveMessage((msg) => {
      if (msg && msg.type === 'rohdReady') {
        readyReceived = true;
        sendContents();
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

    const fsWatcher = vscode.workspace.createFileSystemWatcher(docUri.fsPath);
    const onChange = () => sendContents();
    fsWatcher.onDidChange(onChange);
    fsWatcher.onDidCreate(onChange);
    fsWatcher.onDidDelete(onChange);
    webviewPanel.onDidDispose(() => { fsWatcher.dispose(); readyListener.dispose(); clearTimeout(readyTimeout); });

    webviewPanel.webview.onDidReceiveMessage(async (msg) => {
      if (!msg) return;
      if (msg.type === 'requestSave') {
        if (typeof msg.text === 'string') {
          try {
            await vscode.workspace.fs.writeFile(docUri, Buffer.from(msg.text, 'utf8'));
          } catch (e) { console.warn('Failed to write file from webview', e); }
        } else if (typeof msg.uri === 'string') {
          try {
            const updated = await vscode.workspace.fs.readFile(vscode.Uri.parse(msg.uri));
            await vscode.workspace.fs.writeFile(docUri, updated);
          } catch (e) { console.warn('Failed to read save URI from webview', e); }
        }
      }
    });

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
          const contentType = res.headers.get('content-type') || '';
          if (contentType.indexOf('text') !== -1 || msg.originalUri.toLowerCase().endsWith('.vcd')) {
            const text = await res.text();
            if (window.__rohdMessageCallback) window.__rohdMessageCallback({ type: 'vcdContents', text: text, uri: msg.originalUri });
            try { window.postMessage({ type: 'vcdContents', text: text, uri: msg.originalUri }, '*'); } catch(e) { console.error('postMessage vcdContents failed', e); }
          } else {
            // Binary waveform formats (.fst, .ghw) — fetch as arrayBuffer and forward bytes
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

  html = html.replace(/<body[^>]*>/i, match => match + shimScript + fetchHandler);

  return html;
}

export function deactivate() {}
