from html.parser import HTMLParser
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1] / 'static'
class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids=set(); self.hrefs=[]; self.headings=0; self.scripts=[]
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if 'id' in a: assert a['id'] not in self.ids; self.ids.add(a['id'])
        if 'href' in a: self.hrefs.append(a['href'])
        self.headings += tag == 'h1'
        if tag == 'script': self.scripts.append(a.get('src'))
p=Page(); p.feed((root/'index.html').read_text())
assert p.headings == 1 and p.scripts == ['/interactive.js']
assert (root/'interactive.js').is_file()
for href in p.hrefs:
    if href.startswith('#'): assert href[1:] in p.ids, href
    elif href.startswith('/') and href != '/': assert (root/href.lstrip('/')).is_file(), href
ET.parse(root/'favicon.svg'); ET.parse(root/'sitemap.xml')
assert 'No public installer is available yet' in (root/'index.html').read_text()
assert 'Stereo rendering, head tracking' in (root/'index.html').read_text()
print('PASS: anchors, local assets, SVG/XML, document structure and release-status content')

html = (root/'index.html').read_text()
assert 'view-angle' not in html
assert 'https://tiptontek.com/' in p.hrefs
assert 'https://github.com/johnrtipton/visirupt' in p.hrefs
assert 'polls-list' in p.ids and 'polls-status' in p.ids
print('PASS: community polls, top GitHub link, Tiptontek link and slider removal')
