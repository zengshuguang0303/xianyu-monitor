#!/usr/bin/env python3
"""解析 iOS Cookies.binarycookies，输出 cookie 字符串。
用法: python3 parse_cookie.py <Cookies.binarycookies>
"""
import struct, sys, os

def parse(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'cook':
        raise ValueError('not a binarycookies file')
    num_pages = struct.unpack('>i', data[4:8])[0]
    page_sizes = []
    off = 8
    for _ in range(num_pages):
        page_sizes.append(struct.unpack('>i', data[off:off+4])[0])
        off += 4
    cookies = []
    for ps in page_sizes:
        page = data[off:off+ps]
        off += ps
        # page header: 0x00000100
        num_cookies = struct.unpack('<i', page[4:8])[0]
        offsets = []
        p = 8
        for _ in range(num_cookies):
            offsets.append(struct.unpack('<i', page[p:p+4])[0])
            p += 4
        for co in offsets:
            c = page[co:]
            csize = struct.unpack('<i', c[0:4])[0]
            # c[4:8] unknown/version
            flags = struct.unpack('<i', c[8:12])[0]
            # has_port, port, domain_off, name_off, path_off, value_off
            has_port = c[12]
            real_port = struct.unpack('<i', c[16:20])[0] if has_port else 0
            dom_off = struct.unpack('<i', c[20:24])[0]
            name_off = struct.unpack('<i', c[24:28])[0]
            path_off = struct.unpack('<i', c[28:32])[0]
            val_off = struct.unpack('<i', c[32:36])[0]
            def rd(o):
                end = c.index(b'\0', o)
                return c[o:end].decode('utf-8', 'ignore')
            domain = rd(dom_off)
            name = rd(name_off)
            path_s = rd(path_off)
            value = rd(val_off)
            cookies.append((domain, name, value, path_s))
    return cookies

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('usage: parse_cookie.py <file>'); sys.exit(1)
    cks = parse(sys.argv[1])
    # 输出完整 cookie header
    pairs = [f'{n}={v}' for (d,n,v,p) in cks]
    print('=== total:', len(cks), 'cookies ===')
    print()
    print('--- 完整 Cookie header ---')
    print('; '.join(pairs))
    print()
    print('--- 关键 cookie ---')
    for (d,n,v,p) in cks:
        if n in ('_m_h5_tk','_m_h5_tk_enc','cookie2','_tb_token_','unb','sgcookie','t','cbc','havana_lgc2_77'):
            print(f'{n} = {v}')
