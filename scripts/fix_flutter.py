#!/usr/bin/env python3
"""Fix the flutter_bootstrap.js and extension.js for VS Code webview compatibility.
Copied into scripts/ to centralize script locations.
"""

import re

# Note: This script references local extension installation paths; it should be
# run by a developer who has installed the extension locally.
ext_path = '/home/ganewto/.vscode/extensions/local.rohd-wave-viewer-vscode-0.0.1/out/extension.js'
with open(ext_path, 'r') as f:
    content = f.read()

old_csp = "default-src 'none'; script-src 'unsafe-eval' 'unsafe-inline' ${cspSource}; style-src 'unsafe-inline' ${cspSource}; img-src ${cspSource} data: blob:; connect-src ${cspSource} https:; font-src ${cspSource} data:; worker-src ${cspSource} blob:;"
new_csp = "default-src 'none'; script-src 'wasm-unsafe-eval' 'unsafe-eval' 'unsafe-inline' ${cspSource} https://www.gstatic.com; style-src 'unsafe-inline' ${cspSource}; img-src ${cspSource} data: blob:; connect-src ${cspSource} https: data: blob:; font-src ${cspSource} data:; worker-src ${cspSource} blob:;"

content = content.replace(old_csp, new_csp)

with open(ext_path, 'w') as f:
    f.write(content)
print('Updated CSP in extension.js')
