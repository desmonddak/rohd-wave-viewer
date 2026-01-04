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
    webviewPanel.webview.options = { enableScripts: true, localResourceRoots: [vscode.Uri.joinPath(this.context.extensionUri, 'media')] };

    const indexPath = path.join(this.context.extensionPath, 'media', 'index.html');
    let html = '<h1>Missing build</h1>';
    try { html = fs.readFileSync(indexPath, { encoding: 'utf8' }); } catch (e) { webviewPanel.webview.html = html; return; }

    webviewPanel.webview.html = transformHtml(html, webviewPanel.webview, this.context);

    // Send file contents to webview after the embedded app signals readiness.
    const sendContents = () => {
      console.log('Posting vcdContents to webview for', document.uri.toString());
      webviewPanel.webview.postMessage({ type: 'vcdContents', text: document.getText(), uri: document.uri.toString() });
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

    // Forward messages from webview to host (optional save handling)
    webviewPanel.webview.onDidReceiveMessage(async (msg) => {
      if (msg && msg.type === 'requestSave') {
        const edit = new vscode.WorkspaceEdit();
        edit.replace(document.uri, new vscode.Range(0,0,document.lineCount,0), msg.text);
        await vscode.workspace.applyEdit(edit);
        await document.save();
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

  return html;
}

export function deactivate() {}
