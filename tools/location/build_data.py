"""Build offline coordinates from Census Gazetteer and Natural Earth ZIP archives.
Usage: python3 tools/location/build_data.py /path/zcta.zip /path/cities.zip
Only coordinates/names ship. No network calls occur at runtime.
"""
import csv
import io
import json
import struct
import sys
import zipfile
from collections import defaultdict
from pathlib import Path
from codec import encode

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'config/location'
OUT.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(sys.argv[1]) as archive:
    rows = list(csv.DictReader(io.StringIO(archive.read(archive.namelist()[0]).decode()), delimiter='|'))
# Retain exactly the existing hundredth-degree rounding before lossless encoding.
records = []
for row in sorted(rows, key=lambda r: r['GEOID']):
    records.append((int(row['GEOID']), round((float(row['INTPTLAT'])+90)*100),
                    round((float(row['INTPTLONG'])+180)*100)))
(OUT/'us-zips.bin').write_bytes(encode(records))
with zipfile.ZipFile(sys.argv[2]) as archive:
    data = archive.read('ne_10m_populated_places_simple.dbf')
count, header, width = struct.unpack_from('<IHH', data, 4)
fields = []
for i in range(32, header-1, 32):
    f = data[i:i+32]
    fields.append((f[:11].split(b'\0')[0].decode(), f[16]))
countries = defaultdict(list)
for i in range(count):
    p = header+i*width+1
    row = {}
    for name, size in fields:
        row[name] = data[p:p+size].decode('utf8').strip(); p += size
    name = row['nameascii'] or row['name']
    if row['adm1name']: name += ', ' + row['adm1name']
    countries[row['adm0name']].append([name, round(round(float(row['latitude']), 2)*100), round(round(float(row['longitude']), 2)*100)])
# One small file per country, loaded only while its city picker is open.
index=[]
for i, (country, cities) in enumerate(sorted(countries.items())):
    key = str(i)
    unique = sorted({tuple(c) for c in cities})
    (OUT/f'cities-{key}.json').write_text(json.dumps(unique,ensure_ascii=False,separators=(',',':')))
    index.append([country,key])
(OUT/'countries.json').write_text(json.dumps(index,ensure_ascii=False,separators=(',',':')))
print(f'{len(records)} ZIP areas; {len(index)} countries/territories; {sum(map(len,countries.values()))} cities')
