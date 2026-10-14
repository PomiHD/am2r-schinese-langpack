#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打包发行 zip（dist/）+ 生成 SHA256SUMS

用法: python make_zip.py [--version 1.0.0]

映射关系（仓库源码 → zip 内路径）:
    lang/                    → langpack/lang/
    tools/install-cn.sh      → install-cn.sh
    tools/deck-fullscreen-fix.sh → deck-fullscreen-fix.sh
    docs/说明.txt            → 说明.txt
    docs/font_preview.png    → font_preview.png
zip 内布局必须与 install-cn.sh 的相对路径假设、以及 docs/说明.txt 的说明一致。
"""
import argparse
import hashlib
import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MAP = [('lang', 'langpack/lang'), ('tools/install-cn.sh', 'install-cn.sh'),
       ('tools/deck-fullscreen-fix.sh', 'deck-fullscreen-fix.sh'),
       ('docs/说明.txt', '说明.txt'), ('docs/font_preview.png', 'font_preview.png')]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', default='1.0.0')
    a = ap.parse_args()
    dist = os.path.join(ROOT, 'dist')
    os.makedirs(dist, exist_ok=True)
    zp = os.path.join(dist, f'AM2R-SimplifiedChinese-Langpack-Linux-v{a.version}.zip')
    if os.path.exists(zp):
        os.remove(zp)

    with zipfile.ZipFile(zp, 'w', zipfile.ZIP_DEFLATED) as z:
        for src, arc in MAP:
            p = os.path.join(ROOT, src)
            if os.path.isdir(p):
                for dp, _, fn in os.walk(p):
                    for f in sorted(fn):
                        fp = os.path.join(dp, f)
                        z.write(fp, f'{arc}/{os.path.relpath(fp, p)}'.replace('\\', '/'))
            else:
                z.write(p, arc)

    with zipfile.ZipFile(zp) as z:
        names = sorted(z.namelist())
        print(f'{os.path.basename(zp)}  {os.path.getsize(zp)/1048576:.2f} MB  {len(names)} 个文件')
        for n in names:
            print('   ', n)
        bad = z.testzip()
        assert bad is None, f'zip 损坏: {bad}'

    h = hashlib.sha256(open(zp, 'rb').read()).hexdigest()
    sums = os.path.join(dist, 'SHA256SUMS')
    with open(sums, 'w', newline='\n') as f:
        f.write(f'{h}  {os.path.basename(zp)}\n')
    print(f'\nSHA-256: {h}')
    print('写入', sums)


if __name__ == '__main__':
    main()
