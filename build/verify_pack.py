#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AM2R 简体中文语言包 —— 发布前自检（release gate）

用法:
    python verify_pack.py                                  # 只查包内一致性
    python verify_pack.py --ref-langs "/path/to/official/lang"   # 加上「其它语言 100% 覆盖」检查

检查项:
  1. languages.txt —— 14 行、末行 = schinese.ini、索引 13、无 CR、无末行换行（与官方同格式）
  2. schinese.ini —— UTF-8 BOM、597 条目、0 空值、键集合与官方 english.ini 完全一致(--ref-langs)
  3. fonts/       —— 5 个槽位文件名/大小写正确、每档 100% 覆盖（含其它语言，需 --ref-langs）
  4. sizes.ini    —— 6 个字号 + 3 个偏移键齐全
退出码 0 = 全部通过。
"""
import argparse
import os
import re
import sys

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LANGS = ['english.ini', 'french.ini', 'germanwide.ini', 'german.ini', 'czech.ini', 'spanish.ini',
         'japanese.ini', 'italian.ini', 'russian.ini', 'portuguese-br.ini', 'portuguese-pt.ini',
         'ukrainian.ini', 'swedish.ini', 'schinese.ini']
SLOTS = ['04b09.ttf', '04b24.ttf', 'uni_05_53.ttf', 'Acknowledge_TT_BRK.ttf', 'Glasstown_NBP.ttf']
EXPECT_ENTRIES = 597
# 源字体（Fusion Pixel）本身就没有这几个符号，且任何语言文本都不使用它们 —— 见 README：
# 属于「已知允许缺失」，不算发布失败，但必须显式列出来，不能装作覆盖 100%。
ALLOWED_MISSING = set('✓✕∞∴∵')
fails = []


def norm_path(p):
    """兼容 Git-Bash/MSYS 风格路径（/d/hermes/x → D:/hermes/x），Windows 原生 Python 用"""
    if not p:
        return p
    m = re.match(r'^/([a-zA-Z])/(.*)$', str(p))
    return f'{m.group(1).upper()}:/{m.group(2)}' if m else str(p)



def ok(cond, msg):
    print(('  ✓ ' if cond else '  ✗ ') + msg)
    if not cond:
        fails.append(msg)
    return cond


def parse_ini_pairs(path):
    """返回 [(键, 值)] —— 必须保留重复键（官方 ini 里同一键会出现多次，用 dict 会少数）"""
    pairs = []
    for line in open(path, encoding='utf-8-sig'):
        s = line.strip()
        if s.startswith('[') and s.endswith(']'):
            continue
        if s and '=' in s:
            k, v = s.split('=', 1)
            pairs.append((k.strip(), v.strip().strip('"')))
    return pairs


def parse_ini(path):
    """返回 (段列表, 键值字典) —— 字典用于单值查询（sizes.ini）"""
    secs, d = [], {}
    for line in open(path, encoding='utf-8-sig'):
        s = line.strip()
        if s.startswith('[') and s.endswith(']'):
            secs.append(s)
        elif s and '=' in s:
            k, v = s.split('=', 1)
            d[k.strip()] = v.strip().strip('"')
    return secs, d


def charset_of(path):
    return set(''.join(v for _, v in parse_ini_pairs(path)))


def cmap_of(path):
    t = TTFont(path, lazy=True)
    try:
        return set(t.getBestCmap().keys())
    finally:
        t.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--lang', default=os.path.join(ROOT, 'lang'))
    ap.add_argument('--ref-langs', default=None)
    a = ap.parse_args()
    a.lang = norm_path(a.lang)
    a.ref_langs = norm_path(a.ref_langs)
    L, F = a.lang, os.path.join(a.lang, 'fonts')

    print('[1] languages.txt')
    lt = os.path.join(L, 'languages.txt')
    raw = open(lt, 'rb').read()
    names = raw.decode('utf-8').replace('\r\n', '\n').replace('\r', '\n').split('\n')
    ok(names == LANGS, f'14 行且顺序与官方一致（当前 {len(names)} 行）')
    ok(names[-1] == 'schinese.ini' and names.index('schinese.ini') == 13, 'schinese.ini 位于末位 → 语言索引 13')
    eol = 'CRLF' if b'\r\n' in raw else 'LF'
    mixed = b'\r\n' in raw and raw.replace(b'\r\n', b'').count(b'\n') > 0
    ok(not mixed, f'行尾统一（当前 {eol}；混合行尾会让索引解析出错）')
    ok(not raw.endswith(b'\n'), '末行无换行符（与官方文件同格式）')
    ok(eol == 'CRLF', f'行尾为 CRLF（与官方 languages.txt 逐字节同格式，当前 {eol}）')

    print('[2] schinese.ini')
    ini = os.path.join(L, 'schinese.ini')
    ok(open(ini, 'rb').read(3) == b'\xef\xbb\xbf', 'UTF-8 BOM 存在')
    pairs = parse_ini_pairs(ini)
    ok(len(pairs) == EXPECT_ENTRIES, f'条目数 = {EXPECT_ENTRIES}（当前 {len(pairs)}）')
    empt = [k for k, v in pairs if v == '']
    ok(not empt, f'无空值（{len(empt)} 个）')
    if a.ref_langs:
        en = parse_ini_pairs(os.path.join(a.ref_langs, 'english.ini'))
        ok(len(en) == len(pairs) and {k for k, _ in en} == {k for k, _ in pairs},
           f'与官方 english.ini 逐键对应（官方 {len(en)} / 本包 {len(pairs)}）')

    print('[3] fonts/')
    for n in SLOTS:
        ok(os.path.isfile(os.path.join(F, n)), f'{n} 存在（大小写必须与 GML 一致）')
    chars = charset_of(ini)
    if a.ref_langs:
        ref = set()
        for fn in sorted(os.listdir(a.ref_langs)):
            if fn.endswith('.ini'):
                ref |= charset_of(os.path.join(a.ref_langs, fn))
        chars |= ref
        print(f'    字符集: 中文 {len(charset_of(ini))} ∪ 其它语言 {len(ref)} = {len(chars)}')
    try:  # 与构建脚本共用同一份符号表（口径必须一致）
        sys.path.insert(0, HERE)
        from build_fonts import EXTRA
        chars |= set(EXTRA)
    except ImportError:
        chars |= set(' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`'
                     'abcdefghijklmnopqrstuvwxyz{|}~')
    for n in SLOTS:
        p = os.path.join(F, n)
        if not os.path.isfile(p):
            continue
        cps = cmap_of(p)
        miss = sorted(c for c in chars if ord(c) not in cps and c not in ALLOWED_MISSING)
        known = sorted(c for c in chars if ord(c) not in cps and c in ALLOWED_MISSING)
        ok(not miss, f'{n} 覆盖 {len(chars)} 字符' + ('' if not miss else f'，缺 {len(miss)}: {"".join(miss[:30])}'))
        if known:
            print(f'      （已知允许缺失: {"".join(known)} —— 源字体本无、无语言使用）')

    print('[4] sizes.ini')
    _, sz = parse_ini(os.path.join(F, 'sizes.ini'))
    for k in ['04b09_(large)', '04b09_(small)', '04b24', 'uni_05_53', 'Acknowledge_TT_BRK', 'Glasstown_NBP',
              '04b09_(large)_offset', '04b09_(small)_offset', '04b24_offset']:
        ok(k in sz, f'{k} = {sz.get(k, "缺失")}')

    print()
    if fails:
        print(f'✗ {len(fails)} 项未通过')
        sys.exit(1)
    print('✓ 全部通过')
    if not a.ref_langs:
        print('  提示: 加 --ref-langs <官方 profile 的 lang 目录> 可额外验证「切换其它语言不出方块」')


if __name__ == '__main__':
    main()
