#!/usr/bin/env python3
"""Fix the flutter_bootstrap.js and extension.js for VS Code webview compatibility."""

import re

# 1. Update CSP in extension.js
ext_path = '/home/ganewto/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1/out/extension.js'
with open(ext_path, 'r') as f:
    content = f.read()

# More permissive CSP that allows gstatic.com and wasm
old_csp = "default-src 'none'; script-src 'unsafe-eval' 'unsafe-inline' ${cspSource}; style-src 'unsafe-inline' ${cspSource}; img-src ${cspSource} data: blob:; connect-src ${cspSource} https:; font-src ${cspSource} data:; worker-src ${cspSource} blob:;"
new_csp = "default-src 'none'; script-src 'wasm-unsafe-eval' 'unsafe-eval' 'unsafe-inline' ${cspSource} https://www.gstatic.com; style-src 'unsafe-inline' ${cspSource}; img-src ${cspSource} data: blob:; connect-src ${cspSource} https: data: blob:; font-src ${cspSource} data:; worker-src ${cspSource} blob:;"

content = content.replace(old_csp, new_csp)

with open(ext_path, 'w') as f:
    f.write(content)
print('Updated CSP in extension.js')

# 2. Create a simpler index.html that initializes Flutter without service worker and uses local canvaskit
index_path = '/home/ganewto/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1/media/index.html'

new_index = '''<!DOCTYPE html>
<html>
<head>
  <base href="./">
  <meta charset="UTF-8">
  <meta name="description" content="ROHD Wave Viewer">
  <title>ROHD Wave Viewer</title>
  
  <!-- Embedding shim (exposes window.rohdEmbed) -->
  <script src="embed-shim.js"></script>
</head>
<body>
  <script>
    // Set up Flutter build config to use local canvaskit (no CDN)
    if (!window._flutter) {
      window._flutter = {};
    }
    window._flutter.buildConfig = {
      "engineRevision": "local",
      "builds": [{
        "compileTarget": "dart2js",
        "renderer": "canvaskit",
        "mainJsPath": "main.dart.js"
      }]
    };
  </script>
  <script src="flutter.js"></script>
  <script>
    // Initialize Flutter without service worker, using local canvaskit
    window.addEventListener('load', function() {
      if (window._flutter && window._flutter.loader) {
        window._flutter.loader.load({
          config: {
            canvasKitBaseUrl: "canvaskit/",
            useLocalCanvasKit: true
          },
          onEntrypointLoaded: async function(engineInitializer) {
            let appRunner = await engineInitializer.initializeEngine();
            await appRunner.runApp();
          }
        });
      }
    });
  </script>
</body>
</html>
'''

with open(index_path, 'w') as f:
    f.write(new_index)
print('Updated index.html')

print('Done! Please reload VS Code.')
