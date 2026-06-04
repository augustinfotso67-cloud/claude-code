import sys
print('SCRIPT START', flush=True)
print('argv:', sys.argv, flush=True)
import os
path = sys.argv[1] if len(sys.argv) > 1 else None
print(f'path={path!r}', flush=True)
print(f'exists={os.path.exists(path) if path else None}', flush=True)

import zipfile
import xml.etree.ElementTree as ET
import re

NS = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
RELS = '{http://schemas.openxmlformats.org/officeDocument/2006/relationships}'
PKG_RELS = '{http://schemas.openxmlformats.org/package/2006/relationships}'

z = zipfile.ZipFile(path)
print('opened zip, files:', len(z.namelist()), flush=True)

# Shared strings (probably empty here)
shared = []
if 'xl/sharedStrings.xml' in z.namelist():
    ss = ET.fromstring(z.read('xl/sharedStrings.xml'))
    for si in ss.findall('s:si', NS):
        text = ''.join(t.text or '' for t in si.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t'))
        shared.append(text)
print(f'shared strings: {len(shared)}', flush=True)

wb = ET.fromstring(z.read('xl/workbook.xml'))
sheets_elem = wb.findall('.//s:sheets/s:sheet', NS)
print(f'sheet count: {len(sheets_elem)}', flush=True)

rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
relmap = {r.attrib['Id']: r.attrib['Target'] for r in rels.findall(PKG_RELS + 'Relationship')}
print(f'relmap: {relmap}', flush=True)


def col_idx(letter):
    n = 0
    for c in letter:
        n = n * 26 + (ord(c.upper()) - 64)
    return n - 1


def parse_sheet(path_in_zip):
    root = ET.fromstring(z.read(path_in_zip))
    rows = []
    for row in root.findall('.//s:sheetData/s:row', NS):
        rd = {}
        for c in row.findall('s:c', NS):
            ref = c.attrib.get('r', '')
            t = c.attrib.get('t', 'n')
            m = re.match(r'^([A-Z]+)', ref)
            ci = col_idx(m.group(1)) if m else 0
            v = c.find('s:v', NS)
            ie = c.find('s:is', NS)
            if t == 's' and v is not None:
                idx = int(v.text)
                rd[ci] = shared[idx] if idx < len(shared) else ''
            elif t == 'inlineStr' and ie is not None:
                rd[ci] = ''.join(tn.text or '' for tn in ie.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t'))
            elif v is not None:
                rd[ci] = v.text
        if rd:
            mc = max(rd.keys())
            rows.append([rd.get(i, '') for i in range(mc + 1)])
    return rows


for s in sheets_elem:
    name = s.attrib.get('name')
    rid = s.attrib.get(RELS + 'id')
    target = relmap.get(rid)
    if not target:
        print(f'no target for {rid}', flush=True)
        continue
    target = target.lstrip('/')
    if not target.startswith('xl/'):
        target = 'xl/' + target
    rows = parse_sheet(target)
    print(f'\n========== SHEET: {name} ({len(rows)} rows) ==========', flush=True)
    for i, r in enumerate(rows[:80]):
        print(f'{i+1:>4}: ' + ' | '.join(str(c)[:50] for c in r), flush=True)
    if len(rows) > 80:
        print(f'... ({len(rows) - 80} more)', flush=True)

print('\nSCRIPT END', flush=True)
