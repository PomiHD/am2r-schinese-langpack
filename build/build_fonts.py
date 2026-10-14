#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AM2R 简体中文语言包 —— 字体档位构建（5 个子集 TTF + sizes.ini）

用法:
    python build_fonts.py --ref-langs "/path/to/official/lang"        # 推荐
    python build_fonts.py --ref-langs ... --out lang/fonts --src-fonts build/src_fonts
    python build_fonts.py --ref-langs ... --dry-run                   # 只算字符集，不写文件

  --ref-langs  指向「官方随包语言 ini」所在目录（例如已安装 profile 的 assets/lang）。
               不传也能跑，但子集只含本包中文+符号表 → 切到别的语言会满屏方块，仅用于试验。

为什么要这么绕（改之前先读）:
  1. 游戏把 5 个字体文件名和大小写写死在 GML 里（04b09.ttf / 04b24.ttf / uni_05_53.ttf /
     Acknowledge_TT_BRK.ttf / Glasstown_NBP.ttf），大小写不能改，也不能合并档位。
  2. 这 5 个文件是**共享槽位**：它们原本是官方字体，被换成子集后，只要子集少一个字符，
     那个字符在所有语言下都会变成 ▯。所以子集必须是「本包中文 ∪ 官方其余语言用字 ∪ 符号表」。
  3. 源字体 Fusion Pixel 8px 不含西里尔/希腊字母，用同族 12px 补字；两者 unitsPerEm 不同
     (800 vs 1200)，必须先精确缩放(1.5×, 整数倍像素网格不变)再合并，否则 fontTools 拒绝合并。
  4. 只在「设计尺寸的整数倍」下才锐利：FP8 → 8/16，FP12 → 12/24（见 docs/说明.txt）。
"""
import argparse
import os
import re
import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.scaleUpem import scale_upem
from fontTools.subset import Options, Subsetter
from fontTools.merge import Merger

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # 仓库根
def norm_path(p):
    """兼容 Git-Bash/MSYS 风格路径（/d/hermes/x → D:/hermes/x），Windows 原生 Python 用"""
    if not p:
        return p
    m = re.match(r'^/([a-zA-Z])/(.*)$', str(p))
    return f'{m.group(1).upper()}:/{m.group(2)}' if m else str(p)

# 游戏写死的五个槽位 → 源字体
# 选档依据（官方实测 cap 高 / ascent）:
#   04b09_(large)@16 = 10/12 ; 04b09_(small)@8 = 5/6 ; 04b24@16 = 5/12
#   uni_05_53@8 = 5/9 ; Acknowledge@13 = 5/10 ; Glasstown@16 = 9/13
SLOT_SRC = {
    '04b09.ttf': 8,               # fontGUI(16) + fontSubScr(8)
    '04b24.ttf': 8,               # fontMenuTiny
    'uni_05_53.ttf': 8,           # fontMenuSmall（官方 ascent 9 == FP8@8 ascent 9）
    'Acknowledge_TT_BRK.ttf': 12,  # fontGUI2（官方 13 档，取 12px 中文可读）
    'Glasstown_NBP.ttf': 12,      # fontMenuSmall2（官方 cap 9 == FP12@12）
}

# 符号/标点/假名/希腊字母：官方字体里有、但中文 ini 与其它语言 ini 可能都不含
EXTRA = (
    ' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`'
    'abcdefghijklmnopqrstuvwxyz{|}~'
    '“”‘’…—–·、。，．！？：；（）【】「」『』《》〈〉～￥％＋－×÷＝±°′″'
    '←↑→↓▲▼◀▶■□●○★☆♪♭♯∞∴∵※♦♣♥♠✓✕▯▢▪▫'
    '　'  # 全角空格
    'ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばぱひびぴふぶぺへべぺほぼぽまみむめもゃやゅゆょよらりるれろわをん'
    'ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブヘベホボポマミムメモャヤュユョヨラリルレロワヲンー'
    'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩαβγδεζηθικλμνξοπρστυφχψω'
)

SIZES_INI = """[Sizes]
Defaults = "14, 8, 12, 8, 8, 12"
Ex = "Font sizes are in pixels. 04b09_(small) is usually half of 04b09_(large)."
04b09_(large)="14"
04b09_(small)="8"
Acknowledge_TT_BRK="12"
uni_05_53="8"
04b24="8"
Glasstown_NBP="12"

[Offsets]
Defaults = "-3, -2, -2"
Ex = "These vertical offsets (in pixels) are used when changing the size or vertical positioning of the associated fonts."
04b09_(large)_offset = "-3"
04b09_(small)_offset = "-2"
04b24_offset = "-2"
"""


def read_ini_charset(path):
    chars = set()
    for line in open(path, encoding='utf-8-sig'):
        s = line.strip()
        if not s or s.startswith('[') or '=' not in s:
            continue
        val = s.split('=', 1)[1].strip()
        if val.startswith('"') and val.endswith('"'):
            val = val[1:-1]
        chars |= set(val)
    return chars


def ref_charset(ref_dir):
    """官方随包其它语言用到的全部字符（让别的语言不会变口口口）"""
    chars = set()
    if ref_dir and os.path.isdir(ref_dir):
        for fn in sorted(os.listdir(ref_dir)):
            if fn.endswith('.ini'):
                chars |= read_ini_charset(os.path.join(ref_dir, fn))
    return chars


def cmap_of(path):
    f = TTFont(path, lazy=True)
    try:
        cps = set()
        for tb in f['cmap'].tables:
            cps |= {k for k in tb.cmap.keys() if isinstance(k, int)}
        return cps
    finally:
        f.close()


def subset(src, dst, charset):
    opts = Options()
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.name_legacy = True
    opts.notdef_outline = True
    opts.recalc_bounds = True
    opts.drop_tables += ['DSIG']
    font = TTFont(src, lazy=False)
    sub = Subsetter(options=opts)
    sub.populate(text=''.join(sorted(charset)))
    sub.subset(font)
    font.save(dst)
    font.close()
    if getattr(font, 'reader', None) is not None:
        try:
            font.reader.close()
        except Exception:
            pass


def build_subset(src, dst, charset, fill):
    """子集化；src 缺的字符用同族 fill 补（缺字那份先缩放 upem 再合并）"""
    need = {c for c in charset if ord(c) not in cmap_of(src)}
    fillable = {c for c in need if ord(c) in cmap_of(fill)} if (need and fill) else set()
    if not fillable:
        subset(src, dst, charset)
        return os.path.getsize(dst)

    t1, t2 = dst + '.p1', dst + '.p2'
    subset(src, dst, charset - need)        # 基础部分（不含缺字）
    subset(fill, t2, fillable)              # 要补的字符
    f1, f2 = TTFont(dst, lazy=False), TTFont(t2, lazy=False)
    up = max(f1['head'].unitsPerEm, f2['head'].unitsPerEm)
    if f1['head'].unitsPerEm != up:
        scale_upem(f1, up)
        f1.save(t1)
        base = t1
    else:
        base = dst
    try:
        Merger().merge([base, t2]).save(dst)
    finally:
        for p in (t1, t2):
            if os.path.exists(p):
                try:
                    os.remove(p)
                except Exception:
                    pass
    return os.path.getsize(dst)


def main():
    ap = argparse.ArgumentParser(description='构建 5 档字体子集 + sizes.ini')
    ap.add_argument('--out', default=os.path.join(ROOT, 'lang', 'fonts'))
    ap.add_argument('--src-fonts', default=os.path.join(ROOT, 'build', 'src_fonts'))
    ap.add_argument('--ini', default=os.path.join(ROOT, 'lang', 'schinese.ini'))
    ap.add_argument('--ref-langs', default=None)
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    for k in ('out', 'src_fonts', 'ini', 'ref_langs'):
        setattr(a, k, norm_path(getattr(a, k)))

    fp8 = os.path.join(a.src_fonts, 'fusion-pixel-8px-proportional-zh_hans.ttf')
    fp12 = os.path.join(a.src_fonts, 'fusion-pixel-12px-proportional-zh_hans.ttf')
    for p in (fp8, fp12, a.ini):
        if not os.path.isfile(p):
            sys.exit(f'缺少输入文件: {p}\n（源字体请先跑 build/fetch_fonts.py）')

    cn = read_ini_charset(a.ini)
    ref = ref_charset(a.ref_langs)
    chars = cn | ref | set(EXTRA)
    print(f'字符集: {len(chars)}  = 中文 {len(cn)} ∪ 官方其它语言 {len(ref)} ∪ 符号表 {len(set(EXTRA))}')
    if not ref:
        print('⚠ 未提供 --ref-langs：子集不含其它语言用字，切换语言会出现方块！')
    if a.dry_run:
        return

    os.makedirs(a.out, exist_ok=True)
    for name, px in sorted(SLOT_SRC.items()):
        src = fp8 if px == 8 else fp12
        size = build_subset(src, os.path.join(a.out, name), chars, fill=fp12)
        print(f'  {name:24s} {size/1024:8.1f} KB   (源 FP{px})')

    with open(os.path.join(a.out, 'sizes.ini'), 'w', newline='\r\n', encoding='utf-8') as f:
        f.write(SIZES_INI)
    print(f'  sizes.ini 已写入 {a.out}')

    print('\n覆盖率自检（0 缺失为合格）:')
    for name in sorted(SLOT_SRC):
        cps = cmap_of(os.path.join(a.out, name))
        miss = sorted(c for c in chars if ord(c) not in cps)
        miss_cn = [c for c in miss if c in cn]
        other = [c for c in miss if c not in cn]
        print(f'  {name:24s} ' + ('100% 覆盖' if not miss else
              f'缺 中文{len(miss_cn)} 其它语言{len(other)}  {"".join(miss[:40])}'))


if __name__ == '__main__':
    main()
