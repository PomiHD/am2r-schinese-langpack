#!/usr/bin/env bash
# ============================================================
#  AM2R 简体中文语言包 - 安装器 (Linux / Steam Deck / Flatpak)
#  纯外挂式: 只往 lang/ 目录加文件, 不修改游戏本体 (data.win)
# ============================================================
#  用法:
#    bash install-cn.sh              安装 (自动识别 Flatpak / AppImage 两种布局)
#    bash install-cn.sh --check      只检查当前状态 (不改任何文件)
#    bash install-cn.sh --diag       打印找到的目录结构 (排错用, 不改文件)
#    bash install-cn.sh --uninstall  卸载, 还原到安装前的状态
#    bash install-cn.sh --profile "Community Updates (Latest)"   只处理指定 profile
#    bash install-cn.sh --no-repack  仅 AppImage 布局: 不重新打包 (见输出提示)
#    bash install-cn.sh --no-cwd-shim  不装"切工作目录"的启动 shim (默认装, 见说明)
# ============================================================
set -u

FLATPAK_ID="io.github.am2r_community_developers.AM2RLauncher"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 语言包目录: 兼容两种布局
#   · 发行 zip:  <解压目录>/langpack/lang   (install-cn.sh 与 langpack/ 同级)
#   · 仓库源码:  <仓库>/lang                (install-cn.sh 在 tools/ 下)
if [ -d "$SCRIPT_DIR/langpack/lang" ]; then
    LP="$SCRIPT_DIR/langpack/lang"
else
    LP="$(cd "$SCRIPT_DIR/../lang" 2>/dev/null && pwd || true)"
fi
BK=".am2rcn_backup"          # 被覆盖文件的原件快照
LIST=".am2rcn_added"         # 本次安装写入的文件清单

MODE=install
NOREPACK=0
SHIM=1
PROFILE_FILTER=""
IDX=""

while [ $# -gt 0 ]; do
    case "$1" in
        --check)     MODE=check ;;
        --diag)      MODE=diag ;;
        --uninstall) MODE=uninstall ;;
        --no-repack) NOREPACK=1 ;;
        --no-cwd-shim) SHIM=0 ;;
        --profile)   shift; PROFILE_FILTER="${1:-}" ;;
        -h|--help)   sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "未知参数: $1 (用 --help)"; exit 2 ;;
    esac
    shift
done

if [ ! -d "$LP" ]; then
    echo "错误: 找不到语言包目录 (期望 <脚本目录>/langpack/lang 或 <仓库>/lang)"
    echo "      当前解析结果: $LP"
    echo "请把本脚本放在解压后的语言包文件夹里运行（与 langpack/ 同级），或在仓库里用 tools/install-cn.sh。"
    exit 1
fi

candidate_roots() {
    [ -n "${AM2RLAUNCHERDATA:-}" ] && printf '%s\n' "$AM2RLAUNCHERDATA"
    printf '%s\n' \
        "$HOME/.var/app/$FLATPAK_ID/data/AM2RLauncher" \
        "$HOME/.local/share/AM2RLauncher" \
        "$HOME/.config/AM2RLauncher" \
        "$HOME/AM2RLauncher" \
        "$PWD"
}

# 输出: 类型|profile目录|launcher根目录
discover() {
    local r p pdir seen=""
    while IFS= read -r r; do
        [ -n "$r" ] && [ -d "$r" ] || continue
        # 当前目录只作为"Launcher 根"或"直接是 profile"时才算, 避免误扫无关目录
        if [ "$r" = "$PWD" ] && [ ! -d "$PWD/Profiles" ] && [ ! -f "$PWD/AM2R.AppImage" ]; then continue; fi
        pdir="$r/Profiles"
        [ -d "$pdir" ] || pdir="$r"
        for p in "$pdir"/*/; do
            [ -d "$p" ] || continue
            p="${p%/}"
            [ -n "$PROFILE_FILTER" ] && [ "$(basename "$p")" != "$PROFILE_FILTER" ] && continue
            case "$seen" in *"|$p|"*) continue ;; esac
            seen="$seen|$p|"
            if [ -f "$p/AM2R.AppImage" ]; then
                echo "appimage|$p|$r"
            elif [ -d "$p/assets" ] && { [ -d "$p/assets/lang" ] || [ -f "$p/assets/data.win" ]; }; then
                echo "noappimage|$p|$r"
            elif [ -d "$p/lang" ]; then
                echo "plain|$p|$r"
            fi
        done
    done < <(candidate_roots)
}

# 放一个文件: 目标已存在则先快照原件; 记录到清单
put() {   # put <目标绝对路径> <相对 lang/ 的路径> [源文件]
    local dst="$1"
    local rel="$2"
    local src="${3:-$LP/$rel}"
    [ -f "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -f "$A/lang/$BK/$rel" ] && ! grep -qxF "$rel" "$A/lang/$LIST" 2>/dev/null \
       && ! cmp -s "$dst" "$src" 2>/dev/null; then
        mkdir -p "$A/lang/$BK/$(dirname "$rel")"
        cp -p "$dst" "$A/lang/$BK/$rel" 2>/dev/null || true
    fi
    cp -f "$src" "$dst"
    grep -qxF "$rel" "$A/lang/$LIST" 2>/dev/null || printf '%s\n' "$rel" >> "$A/lang/$LIST"
}

inject() {
    A="$1"
    mkdir -p "$A/lang/fonts" "$A/lang/headers" "$A/lang/titles"
    : >> "$A/lang/$LIST"        # 确保清单存在 (不动已有内容)
    local f b
    # 只注入游戏真正会加载的文件(*.ttf + sizes.ini); 目录里的 README/LICENSE-OFL 不往游戏里拷
    for f in "$LP"/fonts/*.ttf "$LP"/fonts/sizes.ini ; do [ -f "$f" ] && put "$A/lang/fonts/$(basename "$f")"   "fonts/$(basename "$f")";   done
    # 官方 Linux 包会把文件名全部转小写; 若游戏按小写名探测字体, 就会命中官方那个小写副本(字形不全)。
    # 因此把我们的字体在"小写名"下也写一份: 两种大小写探测都能命中我们。Windows(大小写不敏感)上是同一文件, 无害。
    local pair
    for pair in "Acknowledge_TT_BRK.ttf:acknowledge_tt_brk.ttf" "Glasstown_NBP.ttf:glasstown_nbp.ttf"; do
        put "$A/lang/fonts/${pair##*:}" "fonts/${pair##*:}" "$LP/fonts/${pair%%:*}"
    done
    for f in "$LP"/headers/* ; do [ -f "$f" ] && put "$A/lang/headers/$(basename "$f")" "headers/$(basename "$f")"; done
    for f in "$LP"/titles/*  ; do [ -f "$f" ] && put "$A/lang/titles/$(basename "$f")"  "titles/$(basename "$f")";  done
    put "$A/lang/schinese.ini" "schinese.ini"

    local lt="$A/lang/languages.txt"
    if [ ! -f "$lt" ]; then
        # 镜像目录(<profile>/lang)本来没有 languages.txt: 直接用包里的(已含 schinese.ini)
        [ -f "$LP/languages.txt" ] && cp -f "$LP/languages.txt" "$lt" \
            || { echo "  错误: 找不到 languages.txt"; return 1; }
        printf '%s\n' "languages.txt" >> "$A/lang/$LIST"
    else
        # 原本就有的(assets 那份): 先快照原件, 卸载时还原
        # 但若 "languages.txt" 已在我们自己的清单里(是老早注入的), 就不要再快照自己的文件
        if [ ! -f "$A/lang/$BK/languages.txt" ] && ! grep -qxF "languages.txt" "$A/lang/$LIST" 2>/dev/null; then
            mkdir -p "$A/lang/$BK"
            cp -p "$lt" "$A/lang/$BK/languages.txt"
        fi
    fi
    append_language_entry "$lt" || return 1
    IDX=$(( $(grep -nF "schinese.ini" "$lt" | cut -d: -f1 | head -1) - 1 ))
    echo "$IDX" > "$A/lang/.am2rcn_index"
    return 0
}

# 追加 schinese.ini: 沿用原文件行尾(官方是 CRLF), 并处理"末行无换行符"的官方文件
append_language_entry() {
    local lt="$1" eol last
    if grep -qF "schinese.ini" "$lt" 2>/dev/null; then return 0; fi
    # 行尾风格: 用 od 判断(兼容 MSYS/BSD grep 对 $'\r' 的不同处理)
    case "$(head -c 64 "$lt" 2>/dev/null | od -An -c 2>/dev/null)" in
        *'\r'*) eol=$'\r\n' ;;          # 官方文件是 CRLF
        *)      eol=$'\n'  ;;
    esac
    last=$(tail -c 1 "$lt" 2>/dev/null | od -An -tx1 | tr -d ' \n')
    case "$last" in
        ""|0a) : ;;                                  # 空文件 / 已以换行结尾
        *) printf '%s' "$eol" >> "$lt" ;;            # 官方文件末行没有换行符, 先补上
    esac
    printf 'schinese.ini%s' "$eol" >> "$lt"
    echo "  (已在 languages.txt 末尾追加 schinese.ini)"
    return 0
}

uninstall() {
    local A="$1" rel n=0 restored=0
    if [ ! -f "$A/lang/$LIST" ]; then
        echo "  未发现安装记录, 跳过卸载。"; return 0
    fi
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        if [ -f "$A/lang/$BK/$rel" ]; then
            mkdir -p "$(dirname "$A/lang/$rel")"
            cp -f "$A/lang/$BK/$rel" "$A/lang/$rel" && restored=$((restored+1))
        elif [ -f "$A/lang/$rel" ]; then
            rm -f "$A/lang/$rel" && n=$((n+1))
        fi
    done < "$A/lang/$LIST"
    [ -f "$A/lang/$BK/languages.txt" ] && cp -f "$A/lang/$BK/languages.txt" "$A/lang/languages.txt"
    rm -rf "$A/lang/$BK" "$A/lang/$LIST" "$A/lang/.am2rcn_index"
    # 清掉"我们建出来、现在已空"的目录 (非空则 rmdir 自动失败, 不影响原有内容)
    rmdir "$A/lang/fonts" "$A/lang/headers" "$A/lang/titles" "$A/lang" 2>/dev/null || true
    echo "  已还原 $restored 个被覆盖的文件, 移除 $n 个新增文件 (重启游戏即恢复英文)"
}

# ---- 让"不管从哪启动"都成立: 给游戏二进制套一层 shim, 启动前把 CWD 切到 assets ----
# 背景: Launcher 的 Play 按钮与桌面/Steam 快捷方式最终都执行 <profile>/runner,
#       而它最终 exec 的是 <profile>/.runner-unwrapped; 但 Launcher 给的工作目录是 profile 根,
#       游戏数据却在 assets/ 下, 于是裸相对路径 "lang/..." 会落空。
fix_cwd_shim() {
    local p="$1" real="$p/.runner-unwrapped"
    [ -f "$real" ] || return 2                       # 非 NOAPPIMAGE 布局, 跳过
    [ -f "$real.am2rcn-real" ] && return 0           # 已装过, 幂等
    mv -f "$real" "$real.am2rcn-real" || return 1
    cat > "$real" <<'SHIM'
#!/bin/sh
# AM2R 中文语言包: 启动前把工作目录切到 bundle 的 assets 目录。
# 原因: Launcher/快捷方式给进程的工作目录是 profile 根, 而游戏里裸相对路径
#       "lang/fonts/…"、"lang/headers/…"、"lang/titles/…"、"lang/fonts/sizes.ini"
#       是按进程工作目录解析的, 不切目录就找不到, 会静默回退到内置字体。
D=$(cd "$(dirname "$0")" && pwd)
[ -d "$D/assets" ] && cd "$D/assets"
exec "$D/.runner-unwrapped.am2rcn-real" "$@"
SHIM
    chmod +x "$real" 2>/dev/null || true
    return 0
}

unfix_cwd_shim() {
    local p="$1" real="$p/.runner-unwrapped"
    if [ -f "$real.am2rcn-real" ]; then
        rm -f "$real"
        mv -f "$real.am2rcn-real" "$real" && echo "  已还原游戏启动脚本 (.runner-unwrapped)"
    fi
}

state_line() {
    if [ -f "$A/lang/schinese.ini" ] && grep -qF "schinese.ini" "$A/lang/languages.txt" 2>/dev/null; then
        echo "已安装 (语言索引 $(( $(grep -nF 'schinese.ini' "$A/lang/languages.txt" | cut -d: -f1 | head -1) - 1 )))"
    else
        echo "未安装"
    fi
}

set_config_language() {
    local idx="$1" found=0 f
    for f in \
        "$HOME/.config/AM2R/config.ini" \
        "$HOME/.var/app/$FLATPAK_ID/config/AM2R/config.ini" \
        "$HOME/.local/share/AM2R/config.ini" \
        "$HOME/.var/app/$FLATPAK_ID/data/AM2R/config.ini" ; do
        [ -f "$f" ] || continue
        found=1
        if grep -qiE '^Language[[:space:]]*=' "$f"; then
            sed -i -E "s/^(Language[[:space:]]*=).*/\1$idx/" "$f"
        elif grep -qiE '^\[Screen\]' "$f"; then
            sed -i -E "0,/^\[Screen\].*/s//&\nLanguage=$idx/" "$f"
        else
            printf '\n[Screen]\nLanguage=%s\n' "$idx" >> "$f"
        fi
        echo "  已写入语言索引 $idx -> $f"
    done
    [ "$found" = 0 ] && echo "  (未找到 config.ini: 请在游戏内 选项 -> 显示 -> 语言 选一次「简体中文」, 之后会自动记住)"
    return 0
}

# ============================ 主流程 ============================
echo "================================================"
echo " AM2R 简体中文语言包 安装器"
echo "================================================"

mapfile -t FOUND < <(discover)

if [ "${#FOUND[@]}" -eq 0 ]; then
    echo "没有找到任何已安装的 AM2R profile。已查找的位置:"
    candidate_roots 2>/dev/null | sed 's/^/  - /'
    echo
    echo "请在 Launcher 里把游戏「安装(Install)」好之后重新运行本脚本;"
    echo "或用 --diag 查看实际目录结构。"
    exit 1
fi

echo "找到 ${#FOUND[@]} 个 profile:"
for e in "${FOUND[@]}"; do
    IFS='|' read -r t p r <<< "$e"
    case "$t" in
        noappimage) desc="Flatpak / 无 AppImage 布局 (Steam Deck 默认)" ;;
        appimage)   desc="AppImage 布局 (原生 Linux)" ;;
        plain)      desc="直接含 lang/ 的目录" ;;
    esac
    printf '  [%s] %s\n        %s\n        类型: %s\n' "$t" "$(basename "$p")" "$p" "$desc"
done
echo

EXIT=0
for e in "${FOUND[@]}"; do
    IFS='|' read -r t p r <<< "$e"
    echo "-----------------------------------------------"
    echo ">> $(basename "$p")  [$t]"

    if [ "$MODE" = "diag" ]; then
        case "$t" in
            appimage)
                W="$p/.am2rcn_work_diag"; rm -rf "$W"; mkdir -p "$W"
                ( cd "$W" && "$p/AM2R.AppImage" --appimage-extract >/dev/null 2>&1 )
                A="$W/squashfs-root/usr/bin/assets"
                echo "  AppImage 内游戏数据: $A"
                [ -d "$A" ] && ( cd "$A" && find . -maxdepth 2 -path './lang*' | sed 's/^/    /' | head -40 )
                rm -rf "$W"
                continue ;;
            noappimage|plain) A="$p/assets"; [ -d "$A" ] || A="$p" ;;
        esac
        echo "  游戏数据目录: $A"
        echo "  目录结构 (3 层):"
        ( cd "$p" && find . -maxdepth 3 | sed 's/^/    /' | head -40 )
        echo "  lang/ 内容:"
        ( cd "$A/lang" 2>/dev/null && find . -maxdepth 2 | sed 's/^/    /' | head -40 )
        continue
    fi

    case "$t" in
        noappimage)
            A="$p/assets"
            echo "  游戏数据(绝对路径基准): $A"
            echo "  镜像目录(相对路径基准): $p/lang"
            if [ "$MODE" = "uninstall" ]; then
                uninstall "$A"; uninstall "$p"
                unfix_cwd_shim "$p"
            else
                echo "  当前状态: $(state_line "$A") / 镜像: $(state_line "$p")"
                if [ "$MODE" = "install" ]; then
                    if inject "$A"; then
                        IDX_ASSETS="$IDX"
                        echo "  注入完成(assets): schinese.ini + 5 档字体 + 区域横幅 + 标题图  (语言索引 $IDX_ASSETS)"
                        # 关键: 游戏以 <profile> 为进程工作目录启动, 裸相对路径 "lang/..." 是在这里找的
                        if inject "$p"; then
                            echo "  镜像完成(profile 根): $p/lang  (供 lang/fonts、lang/headers、lang/titles、sizes.ini 的相对路径读取)"
                        else
                            echo "  !! 镜像失败"; EXIT=1
                        fi
                        if [ "$SHIM" = 1 ]; then
                            fix_cwd_shim "$p"
                            case $? in
                                0) echo "  启动 shim 已就位: 游戏启动时自动 cd 到 assets (Play 按钮/Steam/桌面快捷方式通吃)" ;;
                                2) echo "  (没有 .runner-unwrapped, 跳过 shim)" ;;
                                *) echo "  !! shim 处理失败 (不影响字体注入)"; EXIT=1 ;;
                            esac
                        fi
                        set_config_language "$IDX_ASSETS"
                    else EXIT=1; fi
                fi
            fi ;;

        appimage)
            W="$p/.am2rcn_work"
            A="$W/squashfs-root/usr/bin/assets"
            if [ "$MODE" = "uninstall" ]; then
                [ -d "$A" ] && uninstall "$A"
                uninstall "$p"
                if [ -f "$p/AM2R.AppImage.am2rcn.orig" ]; then
                    mv -f "$p/AM2R.AppImage.am2rcn.orig" "$p/AM2R.AppImage"
                    echo "  已还原原始 AM2R.AppImage"
                fi
                rm -rf "$W"
                continue
            fi
            need_extract=1
            [ -d "$A" ] && [ "$MODE" = "check" ] && need_extract=0
            if [ "$need_extract" = 1 ]; then
                mkdir -p "$W"
                if [ "$MODE" = "install" ] && { [ ! -f "$p/AM2R.AppImage.am2rcn.orig" ] || [ "$p/AM2R.AppImage" -nt "$p/AM2R.AppImage.am2rcn.orig" ]; }; then
                    cp -f "$p/AM2R.AppImage" "$p/AM2R.AppImage.am2rcn.orig"
                    echo "  已备份原始 AppImage -> AM2R.AppImage.am2rcn.orig"
                fi
                echo "  解包 AppImage (工作目录: $W) ..."
                rm -rf "$W/squashfs-root"
                ( cd "$W" && "$p/AM2R.AppImage" --appimage-extract >/dev/null 2>&1 )
            fi
            if [ ! -d "$A" ]; then echo "  解包失败: 没有生成 $A"; EXIT=1; continue; fi
            if [ "$MODE" = "check" ]; then echo "  当前状态: $(state_line "$A")"; continue; fi
            if ! inject "$A"; then EXIT=1; continue; fi
            IDX_ASSETS="$IDX"
            echo "  注入完成 (语言索引: $IDX_ASSETS)"
            # AppImage 布局下 Launcher 同样以 <profile> 为工作目录, 裸相对 "lang/..." 也要在 profile 根能找到
            inject "$p" && echo "  镜像完成(profile 根): $p/lang"

            AT="$r/PatchData/utilities/appimagetool-x86_64.AppImage"
            if [ "$NOREPACK" = 1 ]; then
                echo "  [--no-repack] 未打包, 运行游戏请用: $W/squashfs-root/AppRun"
                set_config_language "$IDX_ASSETS"; continue
            fi
            if [ -x "$AT" ] || [ -f "$AT" ]; then
                echo "  重新打包 AppImage ..."
                ( cd "$W" && ARCH=x86_64 "$AT" -n squashfs-root >/dev/null 2>&1 ) \
                  || ( cd "$W" && ARCH=x86_64 "$AT" --appimage-extract-and-run -n squashfs-root >/dev/null 2>&1 )
                NEW="$(ls -1t "$W"/*.AppImage 2>/dev/null | grep -v 'squashfs' | head -1)"
                if [ -n "$NEW" ] && [ -f "$NEW" ]; then
                    cp -f "$NEW" "$p/AM2R.AppImage"; chmod +x "$p/AM2R.AppImage"
                    rm -rf "$W"; echo "  新 AppImage 已就位"
                    set_config_language "$IDX_ASSETS"
                else
                    echo "  打包失败 (缺 FUSE / appimagetool 异常)。已保留解包目录, 运行游戏请用:"
                    echo "    $W/squashfs-root/AppRun"
                    EXIT=1
                fi
            else
                echo "  未找到 appimagetool ($AT)"
                echo "  已保留解包目录, 运行游戏请用: $W/squashfs-root/AppRun"
                echo "  (或在 Launcher 里 Install 后重跑本脚本)"
                set_config_language "$IDX_ASSETS"
            fi ;;

        plain)
            A="$p"
            if [ "$MODE" = "uninstall" ]; then uninstall "$A"; else
                echo "  当前状态: $(state_line "$A")"
                [ "$MODE" = "install" ] && { inject "$A" && echo "  注入完成 (语言索引: $IDX)" && set_config_language "$IDX"; }
            fi ;;
    esac
done

echo "-----------------------------------------------"
if [ "$MODE" = "install" ]; then
    echo "完成。进游戏: 选项 -> 显示 -> 语言 -> 简体中文"
    echo "(列表里若已有「简体中文」但字形不对, 说明字体没生效, 用 --diag 把结构发我)"
fi
exit $EXIT
