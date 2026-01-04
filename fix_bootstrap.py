#!/usr/bin/env python3
import re

with open('/home/ganewto/src/rohd/rohd-wave-viewer/build/web/flutter_bootstrap.js', 'r') as f:
    content = f.read()

# Add useLocalCanvasKit
content = content.replace('"engineRevision":', '"useLocalCanvasKit":true,"engineRevision":')

# Replace the load call (remove service worker settings)
content = re.sub(
    r'_flutter\.loader\.load\(\{[^}]+serviceWorkerSettings:[^}]+\}[^}]*\}\);',
    '_flutter.loader.load({});',
    content,
    flags=re.DOTALL
)

with open('/home/ganewto/src/rohd/rohd-wave-viewer/build/web/flutter_bootstrap.js', 'w') as f:
    f.write(content)

print('Done')
