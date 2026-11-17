"""Lossless ZP01 ZIP codec. Integers and index fields use big-endian order.

Header: magic, u32 record count, u16 block size (128). Each index entry is
u24 first ZIP, u32 offset relative to payload. Blocks reset all three previous
values to zero; records contain unsigned ZIP delta and zigzag lat/lon deltas.
Coordinates retain the original offset hundredths, without further rounding.
"""
from bisect import bisect_right
import struct

BLOCK_SIZE = 128


def varint(value):
    if value < 0:
        raise ValueError('negative unsigned integer')
    out = bytearray()
    while value >= 128:
        out.append((value & 127) | 128)
        value >>= 7
    out.append(value)
    return out


def read_varint(data, pos, end):
    value = 0
    for shift in range(0, 35, 7):
        if pos >= end:
            raise ValueError('truncated varint')
        byte = data[pos]
        pos += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, pos
    raise ValueError('oversized varint')


def zigzag(value):
    return 2 * value if value >= 0 else -2 * value - 1


def unzigzag(value):
    return value // 2 if value % 2 == 0 else -(value // 2) - 1


def canonical(records):
    return ''.join(f'{z:05}{a:05}{b:05}' for z, a, b in records).encode('ascii')


def parse_legacy(data):
    if len(data) % 15 or not data.isdigit():
        raise ValueError('invalid legacy records')
    return [tuple(int(data[j:j+5]) for j in range(i, i+15, 5))
            for i in range(0, len(data), 15)]


def encode(records):
    records = list(records)
    previous_zip = 0
    for z, a, b in records:
        if not (previous_zip < z <= 99999 and 0 <= a <= 18000 and 0 <= b <= 36000):
            raise ValueError('invalid or unsorted record')
        previous_zip = z
    payload = bytearray()
    index = bytearray()
    for start in range(0, len(records), BLOCK_SIZE):
        index += records[start][0].to_bytes(3, 'big') + struct.pack('>I', len(payload))
        previous = (0, 0, 0)
        for row in records[start:start+BLOCK_SIZE]:
            payload += varint(row[0]-previous[0])
            payload += varint(zigzag(row[1]-previous[1]))
            payload += varint(zigzag(row[2]-previous[2]))
            previous = row
    return b'ZP01' + struct.pack('>IH', len(records), BLOCK_SIZE) + index + payload


class ZipDatabase:
    def __init__(self, data):
        self.data = data
        if len(data) < 10 or data[:4] != b'ZP01':
            raise ValueError('invalid ZIP header')
        self.count, block_size = struct.unpack_from('>IH', data, 4)
        if block_size != BLOCK_SIZE or self.count > 100000:
            raise ValueError('invalid ZIP dimensions')
        blocks = (self.count + BLOCK_SIZE - 1) // BLOCK_SIZE
        self.payload_start = 10 + blocks * 7
        if self.payload_start > len(data):
            raise ValueError('truncated index')
        self.first = []
        self.offsets = []
        for i in range(blocks):
            p = 10 + i * 7
            self.first.append(int.from_bytes(data[p:p+3], 'big'))
            self.offsets.append(int.from_bytes(data[p+3:p+7], 'big'))
        if self.first != sorted(set(self.first)) or (blocks and self.offsets[0] != 0):
            raise ValueError('invalid index')
        if any(a >= b for a, b in zip(self.offsets, self.offsets[1:])):
            raise ValueError('invalid offsets')
        if any(o >= len(data)-self.payload_start for o in self.offsets):
            raise ValueError('offset outside payload')

    def block(self, i):
        pos = self.payload_start + self.offsets[i]
        end = self.payload_start + self.offsets[i+1] if i+1 < len(self.offsets) else len(self.data)
        previous = (0, 0, 0)
        rows = []
        for _ in range(min(BLOCK_SIZE, self.count-i*BLOCK_SIZE)):
            dz, pos = read_varint(self.data, pos, end)
            da, pos = read_varint(self.data, pos, end)
            db, pos = read_varint(self.data, pos, end)
            row = (previous[0]+dz, previous[1]+unzigzag(da), previous[2]+unzigzag(db))
            if dz == 0 or not (row[0] <= 99999 and 0 <= row[1] <= 18000 and 0 <= row[2] <= 36000):
                raise ValueError('invalid decoded record')
            rows.append(row)
            previous = row
        if pos != end or rows[0][0] != self.first[i]:
            raise ValueError('block does not match index')
        return rows

    def lookup(self, code):
        if isinstance(code, str):
            if len(code) != 5 or not code.isascii() or not code.isdigit():
                return None
            code = int(code)
        if not isinstance(code, int) or not 0 <= code <= 99999:
            return None
        i = bisect_right(self.first, code)-1
        if i < 0:
            return None
        for row in self.block(i):
            if row[0] == code:
                return row
            if row[0] > code:
                break
        return None


def decode(data):
    database = ZipDatabase(data)
    rows = [row for i in range(len(database.first)) for row in database.block(i)]
    if [r[0] for r in rows] != sorted(set(r[0] for r in rows)):
        raise ValueError('overlapping blocks')
    return rows
