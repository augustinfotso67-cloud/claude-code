"""Dump xlsx sheets to plain text using stdlib only (no pandas/openpyxl)."""
import zipfile
import xml.etree.ElementTree as ET
import sys
import re

NS = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
RELS_NS = '{http://schemas.openxmlformats.org/package/2006/relationships}'


def col_letter_to_idx(letter):
    """A->0, Z->25, AA->26"""
    n = 0
    for c in letter:
        n = n * 26 + (ord(c.upper()) - 64)
    return n - 1


def parse_sheet(z, sheet_path, shared_strings):
    xml = z.read(sheet_path)
    root = ET.fromstring(xml)
    rows = []
    for row in root.findall('.//s:sheetData/s:row', NS):
        row_data = {}
        for c in row.findall('s:c', NS):
            ref = c.attrib.get('r', '')
            t = c.attrib.get('t', 'n')
            col_letter = re.match(r'^([A-Z]+)', ref).group(1) if ref else ''
            col_idx = col_letter_to_idx(col_letter) if col_letter else 0
            v = c.find('s:v', NS)
            inline = c.find('s:is', NS)
            if t == 's' and v is not None:
                idx = int(v.text)
                row_data[col_idx] = shared_strings[idx] if idx < len(shared_strings) else ''
            elif t == 'inlineStr' and inline is not None:
                # Combine all text within <is>
                text_parts = []
                for tnode in inline.iter():
                    if tnode.tag == '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t':
                        text_parts.append(tnode.text or '')
                row_data[col_idx] = ''.join(text_parts)
            elif v is not None:
                row_data[col_idx] = v.text
        if row_data:
            max_col = max(row_data.keys())
            row_list = [row_data.get(i, '') for i in range(max_col + 1)]
            rows.append(row_list)
    return rows


def main():
    path = sys.argv[1]
    sheet_filter = sys.argv[2] if len(sys.argv) > 2 else None
    max_rows = int(sys.argv[3]) if len(sys.argv) > 3 else 50

    z = zipfile.ZipFile(path)

    # Shared strings
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        ss = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for si in ss.findall('s:si', NS):
            text = ''.join(t.text or '' for t in si.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t'))
            shared.append(text)

    # Workbook sheets
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    sheet_meta = []
    for s in wb.findall('.//s:sheets/s:sheet', NS):
        sheet_meta.append({
            'name': s.attrib.get('name'),
            'rid': s.attrib.get(RELS_NS + 'id'),
        })

    rels = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    relmap = {r.attrib['Id']: r.attrib['Target'] for r in rels.findall(RELS_NS + 'Relationship')}

    for sm in sheet_meta:
        if sheet_filter and sheet_filter.lower() not in sm['name'].lower():
            continue
        target = relmap.get(sm['rid'])
        if not target:
            continue
        full_path = 'xl/' + target if not target.startswith('xl/') else target
        rows = parse_sheet(z, full_path, shared)
        print(f'\n========== SHEET: {sm["name"]} ({len(rows)} rows) ==========')
        for i, r in enumerate(rows[:max_rows]):
            cells = ' | '.join(str(c)[:60] for c in r)
            print(f'{i+1:>4}: {cells}')
        if len(rows) > max_rows:
            print(f'... ({len(rows) - max_rows} more rows)')


if __name__ == '__main__':
    main()
