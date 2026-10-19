# Generates the app icon SVGs: python3 generate_icons.py <out_dir>
# (render to PNGs with cairosvg; see the commit that added this file).
import sys
out = sys.argv[1]

BG = '''<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#2D6BD6"/>
    <stop offset="0.55" stop-color="#1A4FA6"/>
    <stop offset="1" stop-color="#0B2A63"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.3" cy="0.22" r="0.75">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
</defs>'''

def background(rx):
    return f'<rect width="1024" height="1024" rx="{rx}" fill="url(#bg)"/><rect width="1024" height="1024" rx="{rx}" fill="url(#glow)"/>'

def mark(white='#FFFFFF', base='#D6E3FA', accent='#FFB61E', hole='#1A4FA6', ring='#123E86', mono=False):
    if mono:
        white = base = accent = '#FFFFFF'
    return f'''
  <!-- cap band -->
  <path d="M332 500 L332 640 Q512 735 692 640 L692 500 Z" fill="{base}"/>
  <!-- board -->
  <path d="M512 300 L842 438 L512 576 L182 438 Z" fill="{white}" stroke="{white}" stroke-width="18" stroke-linejoin="round"/>
  <!-- button -->
  <circle cx="512" cy="438" r="20" fill="{hole if not mono else '#000000'}" {'' if not mono else 'fill-opacity="0"'}/>
  <!-- tassel -->
  <path d="M512 438 L778 476 L778 610" fill="none" stroke="{accent}" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="778" cy="652" r="52" fill="{ring if not mono else '#FFFFFF'}"/>
  <circle cx="778" cy="652" r="42" fill="{accent}"/>
'''

def svg(body, size=1024):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024">{BG}{body}</svg>'

def scaled(m, s):
    # scale the mark around the centre (adaptive icons need it smaller)
    return f'<g transform="translate(512 512) scale({s}) translate(-512 -512)">{m}</g>'

files = {
  'icon.svg': svg(background(0) + scaled(mark(), 1.06)),                      # square (iOS, store)
  'icon_rounded.svg': svg(background(228) + scaled(mark(), 1.06)),            # legacy Android, web
  'foreground.svg': svg(scaled(mark(), 0.8)),                  # adaptive foreground
  'background.svg': svg(background(0)),                         # adaptive background
  'monochrome.svg': svg(scaled(mark(mono=True), 0.8)),         # Android 13 themed icon
  'mark.svg': svg(scaled(mark(), 1.18)),                        # in-app logo on themed tile
}
for name, data in files.items():
    open(f'{out}/{name}', 'w').write(data)
