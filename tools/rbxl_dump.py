import sys, struct, os, json
from collections import defaultdict
try:
    from compression import zstd
    zdec = zstd.decompress
except Exception:
    import zstandard; zdec = lambda b: zstandard.ZstdDecompressor().decompress(b)

def lz4_block(src, usize):
    out = bytearray(); i = 0
    while i < len(src):
        t = src[i]; i += 1
        ll = t >> 4
        if ll == 15:
            while True:
                b = src[i]; i += 1; ll += b
                if b != 255: break
        out += src[i:i+ll]; i += ll
        if i >= len(src): break
        off = src[i] | (src[i+1] << 8); i += 2
        ml = t & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255: break
        ml += 4
        for _ in range(ml): out.append(out[-off])
    return bytes(out)

def unz(s, n):
    return zdec(s) if s[:4] == b'\x28\xb5\x2f\xfd' else lz4_block(s, n)

def deint(buf, count, size):
    return [bytes(buf[b*count+i] for b in range(size)) for i in range(count)]
def i32s(buf, count):
    out = []
    for raw in deint(buf, count, 4):
        v = int.from_bytes(raw, 'big'); out.append((v >> 1) ^ -(v & 1))
    return out
def delta(a):
    r = []; t = 0
    for x in a: t += x; r.append(t)
    return r

d = open(sys.argv[1], 'rb').read()
assert d[:8] == b'<roblox!'
ncls, ninst = struct.unpack_from('<ii', d, 16)
p = 32
classes = {}; inst_cls = {}; props = defaultdict(dict); parent = {}
while p < len(d):
    tag = d[p:p+4]; cl, ul = struct.unpack_from('<II', d, p+4); p += 16
    raw = d[p:p+(cl or ul)]; p += cl or ul
    data = unz(raw, ul) if cl else raw
    if tag == b'INST':
        cid, = struct.unpack_from('<I', data, 0); nl, = struct.unpack_from('<I', data, 4)
        name = data[8:8+nl].decode(); q = 8+nl; fmt = data[q]; cnt, = struct.unpack_from('<I', data, q+1); q += 5
        refs = delta(i32s(data[q:q+4*cnt], cnt)); classes[cid] = (name, refs)
        for r in refs: inst_cls[r] = name
    elif tag == b'PROP':
        cid, = struct.unpack_from('<I', data, 0); nl, = struct.unpack_from('<I', data, 4)
        pname = data[8:8+nl].decode(); q = 8+nl; typ = data[q]; q += 1
        refs = classes[cid][1]
        if typ == 1:
            for r in refs:
                l, = struct.unpack_from('<I', data, q); q += 4
                props[r][pname] = data[q:q+l].decode('utf-8', 'replace'); q += l
        elif typ == 2:
            for k, r in enumerate(refs): props[r][pname] = bool(data[q+k])
        elif typ == 3:
            for r, v in zip(refs, i32s(data[q:q+4*len(refs)], len(refs))): props[r][pname] = v
    elif tag == b'PRNT':
        cnt, = struct.unpack_from('<I', data, 1); q = 5
        ch = delta(i32s(data[q:q+4*cnt], cnt)); q += 4*cnt
        pa = delta(i32s(data[q:q+4*cnt], cnt))
        parent = dict(zip(ch, pa))
    elif tag == b'END\x00': break

def path(r):
    parts = []
    while r in parent and r != -1:
        parts.append(props[r].get('Name', inst_cls[r])); r = parent[r]
    return '/'.join(reversed(parts))
rows = sorted((path(r), inst_cls[r], r) for r in inst_cls)
out = sys.argv[2]; os.makedirs(out, exist_ok=True)
with open(out + '/tree.txt', 'w') as f:
    for pth, c, r in rows: f.write(f'{c}\t{pth}\n')
n = 0
for pth, c, r in rows:
    if c in ('Script', 'LocalScript', 'ModuleScript') and 'Source' in props[r]:
        fn = out + '/scripts/' + pth.replace('/', '__') + f'.{c}.lua'
        os.makedirs(out + '/scripts', exist_ok=True); open(fn, 'w').write(props[r]['Source']); n += 1
print('instances', len(inst_cls), 'classes', len(classes), 'scripts', n)
