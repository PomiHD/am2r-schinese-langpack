#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""下载并校验 Fusion Pixel 源字体（字体档位构建的输入）

用法:
    python fetch_fonts.py                 # 下载到 build/src_fonts/ 并校验 SHA-256
    python fetch_fonts.py --dir /tmp/fp   # 指定目录

固定版本: Fusion Pixel Font 2026.09.25 (TakWolf, SIL OFL 1.1)
  https://github.com/TakWolf/fusion-pixel-font
只取这两个文件（zh_hans 等宽比例版的比例版）:
  fusion-pixel-8px-proportional-zh_hans.ttf   3,655,972 B
  fusion-pixel-12px-proportional-zh_hans.ttf  7,053,672 B
"""
import argparse
import hashlib
import os
import sys
import urllib.request
import zipfile

VERSION = '2026.09.25'
BASE = f'https://github.com/TakWolf/fusion-pixel-font/releases/download/{VERSION}'

# 需要从每个 zip 里取出的文件 → SHA-256（我们是按这两个哈希校验过的）
WANTED = {
    'fusion-pixel-8px-proportional-zh_hans.ttf': 'fe3a1201856d4889094a8c084bbe123fac754ba9be0e5a3e78d36900b0d75df8',
    'fusion-pixel-12px-proportional-zh_hans.ttf': 'b2ee68647dc257fa697e4d0c78f9b59461bc504a023b9a3b5ad66f358bbb1613',
}
ZIPS = {
    8: 'fusion-pixel-font-8px-proportional-ttf-v%s.zip' % VERSION,
    12: 'fusion-pixel-font-12px-proportional-ttf-v%s.zip' % VERSION,
}
HERE = os.path.dirname(os.path.abspath(__file__))


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dir', default=os.path.join(HERE, 'src_fonts'))
    a = ap.parse_args()
    os.makedirs(a.dir, exist_ok=True)

    todo = [n for n in WANTED if not (os.path.isfile(os.path.join(a.dir, n))
                                     and sha256(os.path.join(a.dir, n)) == WANTED[n])]
    if not todo:
        print('源字体已就位且校验通过:', a.dir)
        return

    for px, zname in ZIPS.items():
        url = f'{BASE}/{zname}'
        zpath = os.path.join(a.dir, zname)
        print(f'下载 {zname} …', flush=True)
        tmp = zpath + '.part'
        urllib.request.urlretrieve(url, tmp)   # 走系统代理（如需）
        os.replace(tmp, zpath)
        with zipfile.ZipFile(zpath) as z:
            for member in z.namelist():
                base = os.path.basename(member)
                if base in WANTED:
                    with z.open(member) as src, open(os.path.join(a.dir, base), 'wb') as dst:
                        dst.write(src.read())
        os.remove(zpath)

    ok = True
    for name, want in WANTED.items():
        p = os.path.join(a.dir, name)
        if not os.path.isfile(p):
            print(f'✗ 未取到 {name}')
            ok = False
            continue
        got = sha256(p)
        mark = '✓' if got == want else '✗'
        if got != want:
            ok = False
        print(f'{mark} {name}  {os.path.getsize(p)} B  sha256={got[:16]}…')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
