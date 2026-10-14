#!/usr/bin/env bash
# ============================================================
#  AM2R Steam Deck 全屏画面错乱 —— 修复脚本
#  不改游戏本体(data.win)，只改游戏的显示设置(config.ini)
# ------------------------------------------------------------
#  症状: 桌面模式正常, 掌机模式一旦开"全屏"画面就错位/上下割裂
#  原因: AM2R(GameMaker 1.4)自带的全屏模式在 Deck 的 gamescope 下会出错;
#        社区(r/AM2R)与官方 1.5 说明都证实: 全屏=开 时启动就会画面错乱。
#  方案: 关掉游戏自带全屏 + 窗口设为 3x(1278x720, 正好放进 1280x800),
#        由 gamescope 做整数缩放 + 像素过滤 —— 观感等同全屏但不再错乱。
#
#  用法:
#    bash deck-fullscreen-fix.sh            应用修复(先备份 config.ini)
#    bash deck-fullscreen-fix.sh --check    只看当前设置, 不改
#    bash deck-fullscreen-fix.sh --restore  还原到修复前
# ============================================================
set -u

MODE=fix
while [ $# -gt 0 ]; do
    case "$1" in
        --check)   MODE=check ;;
        --restore) MODE=restore ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) echo "未知参数: $1 (用 --help)"; exit 2 ;;
    esac
    shift
done

FLATPAK_ID="io.github.am2r_community_developers.AM2RLauncher"
BAK_SUFFIX=".am2rcn-displaybak"

# config.ini 可能的位置(Flatpak 沙箱内的 XDG_CONFIG_HOME 优先)
find_configs() {
    local f
    for f in \
        "$HOME/.var/app/$FLATPAK_ID/config/AM2R/config.ini" \
        "$HOME/.config/AM2R/config.ini" \
        "$HOME/.var/app/$FLATPAK_ID/data/AM2R/config.ini" \
        "$HOME/.local/share/AM2R/config.ini" ; do
        [ -f "$f" ] && printf '%s\n' "$f"
    done
}

getv() {   # getv <file> <key>
    grep -iE "^$2[[:space:]]*=" "$1" 2>/dev/null | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/"//g' | tr -d '\r'
}

setv() {   # setv <file> <key> <value>   写成游戏自己的格式 "3.000000"
    local f="$1" k="$2" v="$3"
    if grep -qiE "^${k}[[:space:]]*=" "$f"; then
        sed -i -E "s|^(${k}[[:space:]]*=).*|\1\"${v}\"|" "$f"
    else
        printf '%s="%s"\n' "$k" "$v" >> "$f"
    fi
}

show() {   # show <file>
    local f="$1" fs sc ws vs
    fs=$(getv "$f" Fullscreen); sc=$(getv "$f" Scale); ws=$(getv "$f" Widescreen); vs=$(getv "$f" VSync)
    echo "  $f"
    echo "    Fullscreen=$fs  Scale=$sc  Widescreen=$ws  VSync=$vs"
    case "$sc" in
        1|1.0*|1.000000) echo "    → 窗口: 426x240 (16:9) / 320x240 (4:3)";;
        2|2.0*|2.000000) echo "    → 窗口: 852x480 / 640x480";;
        3|3.0*|3.000000) echo "    → 窗口: 1278x720 / 960x720  ← Deck 推荐(1280x800 屏幕)";;
        *)               echo "    → 窗口: 约 426x240 × Scale=$sc";;
    esac
}

echo "=================================================="
echo " AM2R Steam Deck 显示修复 (不改游戏本体)"
echo "=================================================="

FOUND=$(find_configs)
if [ -z "$FOUND" ]; then
    echo "没找到 config.ini。已查找:"
    echo "  ~/.var/app/$FLATPAK_ID/config/AM2R/config.ini"
    echo "  ~/.config/AM2R/config.ini  等"
    echo
    echo "先启动一次游戏(会自动生成 config.ini), 再运行本脚本;"
    echo "或者直接在游戏里改: 选项 → 显示 → 全屏=关, 显示比例/窗口大小=3x"
    exit 1
fi

echo "找到以下 config.ini:"
echo "$FOUND" | sed 's/^/  /'
echo

case "$MODE" in
    check)
        echo "当前显示设置:"
        while IFS= read -r f; do show "$f"; done <<< "$FOUND"
        echo
        echo "推荐的 Deck 设置: Fullscreen=0(关)  Scale=3.000000  (全屏错乱的根因就是 Fullscreen=开启)"
        ;;
    restore)
        n=0
        while IFS= read -r f; do
            if [ -f "$f$BAK_SUFFIX" ]; then
                cp -f "$f$BAK_SUFFIX" "$f"; rm -f "$f$BAK_SUFFIX"
                echo "  已还原: $f"; n=$((n+1))
            else
                echo "  (没有备份, 跳过): $f"
            fi
        done <<< "$FOUND"
        [ "$n" = 0 ] && echo "没有任何备份——本脚本可能没运行过。" || echo "完成。建议进游戏确认显示正常。"
        ;;
    fix)
        while IFS= read -r f; do
            [ -f "$f$BAK_SUFFIX" ] || cp -p "$f" "$f$BAK_SUFFIX"
            echo "  修改前:"; show "$f"
            # 关键三行: 关全屏 / 窗口 3x / 保持宽屏
            setv "$f" Fullscreen "0.000000"
            setv "$f" Scale      "3.000000"
            [ -n "$(getv "$f" Widescreen)" ] || setv "$f" Widescreen "1.000000"
            echo "  修改后:"; show "$f"
            echo "  (原件已备份为 $(basename "$f")$BAK_SUFFIX)"
            echo
        done <<< "$FOUND"
        cat <<'TIP'
──────────────────────────────────────────────────────────
还要在 Steam Deck 上做两步(否则画面会被拉伸/发虚):

1) 前提: 游戏要作为"非 Steam 游戏"加进 Steam, 从**掌机模式**启动
   (桌面模式下 Deck 内置手柄只当鼠标键盘用, 且没有 gamescope 缩放)

2) 按 Deck 的 [···] 键 → 性能菜单 → 确认改的是"当前游戏"的配置档, 然后:
     · 缩放模式 (Scaling Mode):  整数 / Integer
     · 缩放滤镜 (Scaling Filter): 像素 / Pixel
   (不想要上下两条黑边、且接受轻微拉伸的话, 缩放模式选"拉伸/Stretch"亦可)

3) 如果仍然错乱(个别系统版本), 在该条目的 Steam 属性 → 启动选项里填:
     xprop -root -remove GAMESCOPE_FORCE_WINDOWS_FULLSCREEN; %command%

想还原: bash deck-fullscreen-fix.sh --restore
──────────────────────────────────────────────────────────
TIP
        ;;
esac
