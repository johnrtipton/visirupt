from html.parser import HTMLParser
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1] / 'static'
class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids=set(); self.hrefs=[]; self.headings=0; self.scripts=0
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if 'id' in a: assert a['id'] not in self.ids; self.ids.add(a['id'])
        if 'href' in a: self.hrefs.append(a['href'])
        self.headings += tag == 'h1'; self.scripts += tag == 'script'
p=Page(); p.feed((root/'index.html').read_text())
assert p.headings == 1 and p.scripts == 0
for href in p.hrefs:
    if href.startswith('#'): assert href[1:] in p.ids, href
    elif href.startswith('/') and href != '/': assert (root/href.lstrip('/')).is_file(), href
ET.parse(root/'favicon.svg'); ET.parse(root/'sitemap.xml')
assert 'No public installer is available yet' in (root/'index.html').read_text()
assert 'Stereo rendering, head tracking' in (root/'index.html').read_text()
print('PASS: anchors, local assets, SVG/XML, document structure and release-status content')
