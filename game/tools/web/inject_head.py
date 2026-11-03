# Writes the web export's <head> extras into export_presets.cfg: home-screen web-app tags (full screen when launched
# from the iPhone home screen) and web/landscape.js inlined (the game turns sideways on a phone held upright).
#   python3 game/tools/web/inject_head.py
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, '..', '..')
js = open(os.path.join(GAME, 'web', 'landscape.js')).read()
assert '"' not in js, 'landscape.js must not contain double quotes (it goes inside a cfg string)'
js = '\n'.join(line for line in js.splitlines() if not line.strip().startswith('//'))
head = ("<meta name='viewport' content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover'>"
        "<meta name='apple-mobile-web-app-capable' content='yes'><meta name='mobile-web-app-capable' content='yes'>"
        "<meta name='apple-mobile-web-app-status-bar-style' content='black-translucent'>"
        "<meta name='apple-mobile-web-app-title' content='Cinder & Crown'>"
        "<script>" + js.replace('\\', '\\\\') + "</script>")
path = os.path.join(GAME, 'export_presets.cfg')
cfg = open(path).read()
cfg, n = re.subn(r'^html/head_include=".*?"$', lambda m: 'html/head_include="' + head.replace('\n', '\\n') + '"', cfg, flags=re.M | re.S)
assert n == 1, n
open(path, 'w').write(cfg)
print('head_include written, %d chars' % len(head))
