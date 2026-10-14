# AM2R 简体中文语言包（Linux / Steam Deck / Flatpak）

给官方 **AM2RLauncher** 分发的 *AM2R: Community Updates 1.5.x* 补上**简体中文**——在 Linux、Steam Deck（Flatpak）上开箱可玩。

- **纯外挂**：只往游戏的 `lang/` 目录里加文件，**不修改游戏本体**（完全不碰 `data.win`），一条命令即可卸载还原。
- **自带中文字体**：官方随包的 5 档字体汉字覆盖率只有 **0% ~ 69%**，不换字体必然满屏方块；本包换成开源像素字体的子集。
- **不破坏其它语言**：字体子集 = 本包中文 ∪ 官方随包其余 14 种语言用字（共 2051 字符），切回英/日/俄/德/乌克兰语依旧正常，不会变 ▯。
- **不向上游提交任何内容**：本仓库只是个人发布，原因见「[与上游社区的关系](#与上游社区的关系--ai-使用声明)」。

> ⚠️ 非官方粉丝作品，与 AM2R 原作者 DoctorM64、AM2R Community Updates 开发团队**均无关联**。
> 本仓库**不包含任何游戏本体或游戏素材**；请先通过官方 AM2RLauncher 自行安装游戏（正版渠道），再使用本语言包。

---

## 快速开始（Steam Deck / Linux 三步）

```bash
# 1. 下载 dist/ 里的 zip 并解压（或直接克隆本仓库）
unzip AM2R-SimplifiedChinese-Langpack-Linux-v1.0.0.zip -d ~/am2r-cn

# 2. 先确认游戏已装好：AM2RLauncher → Play → Install（profile: Community Updates (Latest)）

# 3. 注入语言包（自动识别 Flatpak / AppImage 两种布局）
cd ~/am2r-cn && bash install-cn.sh
```

装好后启动游戏：**Options（选项） → Display（显示） → Language（语言） → 简体中文**（只需选一次，会记住）。

想撤销：`bash install-cn.sh --uninstall` —— 被覆盖的文件按快照还原、新增的文件删除，回到安装前的状态。

> **注意**：AM2RLauncher 每次 **更新 / 重装 profile** 都会覆盖 `lang/`（Flatpak 版连 `assets/` 一起覆盖）。
> 更新完**重跑一次 `install-cn.sh`** 即可。

---

## 这个语言包做了什么

官方 Community Updates 只随包 13 种语言（英法德西捷日意俄葡葡巴乌瑞典），**不含中文**。
中文翻译由 **Hambaka** 等人在社区本地化仓库的 **PR #16** 提供，但因为字体问题一直没有合并、也没有随官方包分发。

所以「把 `schinese.ini` 丢进去」是不够的——必须同时解决字体，否则满屏方块：

| 官方随包字体 | 用途 | 汉字覆盖 |
|---|---|---|
| `04b09.ttf` / `04b24.ttf` | 主菜单、HUD、装备列表 | **0%**（不含任何汉字） |
| `uni_05_53.ttf` | HUD、地图、通知 | ~69%（且有 356 个常用汉字缺失、字形为日文写法） |
| `Acknowledge_TT_BRK.ttf` / `Glasstown_NBP.ttf` | 日志、过场、选项标签 | 同上 |

本包的解法：**替换这 5 个共享字体槽位为开源像素字体 [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)（TakWolf, SIL OFL 1.1）的简体字形子集**，
子集范围刻意做成「本包中文 ∪ 官方其它 14 种语言用字 = **2051 字符**」，所以换语言不会互相踩。
其中 8px 档的源字体本身不含西里尔/希腊字母，用同族 12px 版补入（先把 upem 800 精确缩放到 1200 再合并，像素网格对齐）。

> 另有一个 Linux 专属的历史遗留问题：Launcher 在 Unix 上会把装好的文件名**全部转小写**（`HelperMethods.LowercaseFolder`），
> 而游戏里写死要读 `Acknowledge_TT_BRK.ttf` / `Glasstown_NBP.ttf`（大写，且有 `file_exists` 保护）——
> 于是**官方 Linux 版其实从来没加载过这两档字体**。本包按 GML 原样大小写放置，并额外派生小写别名，两种情况下都能命中。

---

## 仓库内容

```
lang/                     语言包源文件（= zip 里 langpack/lang/ 的内容，可直接拷贝使用）
  ├─ schinese.ini         翻译文本：597 条，与官方 1.5.5 英文版逐键对应，无缺失、无空值
  ├─ languages.txt        语言列表：schinese.ini 追加在末位（索引 13）
  ├─ fonts/               5 档字体子集 + sizes.ini + 字体许可（OFL）
  ├─ headers/             7 张区域过场横幅（1/2/3/4/5/7/8 区）
  └─ titles/              标题图「AM2R 萨姆斯的回归」
tools/
  ├─ install-cn.sh        安装器：Flatpak / AppImage / 普通目录三种布局、幂等、可卸载
  └─ deck-fullscreen-fix.sh  Steam Deck 全屏画面错乱修复（只改 config.ini）
docs/
  ├─ 说明.txt             完整中文说明书（随 zip 一起分发的那份，含全部坑与排错）
  └─ font_preview.png     字体样张
build/                    构建与校验脚本（可复现）：抓取源字体 → 生成字体子集 → 发布前自检 → 打包
dist/                     发行 zip + SHA256SUMS
```

---

## 安装器参数

```
bash tools/install-cn.sh              # 安装（自动识别布局）
bash tools/install-cn.sh --check      # 只看现状，不改任何文件
bash tools/install-cn.sh --diag       # 打印探测到的目录结构（排错用）
bash tools/install-cn.sh --uninstall  # 卸载还原到安装前
bash tools/install-cn.sh --profile "Community Updates (Latest)"   # 只处理指定 profile
bash tools/install-cn.sh --no-repack  # 仅 AppImage 布局：不回包，直接跑解包后的 AppRun
bash tools/install-cn.sh --no-cwd-shim  # 不装「启动前切工作目录」的 shim
```

脚本是**幂等**的，重复执行没有副作用；安装时会在 `lang/` 里留两个记账文件（`.am2rcn_added` / `.am2rcn_backup`），卸载时自动清理。

---

## Steam Deck：掌机模式全屏画面错乱（与本语言包无关）

如果你在 Deck 掌机模式下遇到**画面错位 / 上下割裂成两块**，那不是语言包造成的，而是 AM2R 自带的全屏模式在 gamescope 下就会出问题。
r/AM2R 的结论帖写得很明确：*"Steam Deck users: Here's the settings to get the game pixel-perfect **without any glitched video on startup** and with no need to bind a button to F11"* ——
其中 **Fullscreen: Enabled 就是启动错乱的来源**，另一帖的答复也是「把 `config.ini` 的 fullscreen 改回关闭」。

解法（**不改游戏本体**，只改显示设置）：

```bash
bash tools/deck-fullscreen-fix.sh            # 应用：Fullscreen=0、窗口缩放=3x（先备份）
bash tools/deck-fullscreen-fix.sh --check    # 只看当前值
bash tools/deck-fullscreen-fix.sh --restore  # 还原
```

然后在 Deck 上补两步（无法脚本化）：
1. 把游戏作为**非 Steam 游戏**添加，并从**掌机模式**启动（桌面模式内置手柄走的是模拟键鼠，且没有 gamescope 缩放）；
2. `[···]` → 性能菜单 → 确认改的是**当前游戏**的配置档 → **缩放模式 = 整数**，**缩放滤镜 = 像素**。

观感等同全屏、像素级锐利、不再错乱（上下各留一条极细黑边；要铺满就把缩放模式改「拉伸」）。
个别系统版本仍错乱时，在该条目「属性 → 启动选项」填：

```
xprop -root -remove GAMESCOPE_FORCE_WINDOWS_FULLSCREEN; %command%
```

---

## 平台差异（都是踩过的坑）

**Windows** — Launcher 重装/更新 profile 会覆盖 `lang/`，重新把 `lang/` 复制回去即可；文件系统大小写不敏感，没有下面的问题。

**Linux / Steam Deck（Flatpak）**
- **Deck 上没有 `AM2R.AppImage`**：Flathub 版用 `NOAPPIMAGE` 常量编译（manifest: `-p:DefineConstants="NOAPPIMAGE;NOAUTOUPDATE"`），profile 里是 `runner` + `.runner-unwrapped` + `assets/` + `profile.xml`，游戏数据在 `assets/lang/`。
- **工作目录 ≠ 游戏数据目录**（最关键）：Launcher 把进程工作目录设成 **profile 根目录**（`Profile.cs` 的 `WorkingDirectory = {ProfilesPath}/{profile.Name}`），而数据在 `<profile>/assets/`。于是游戏里两套路径写法命运不同：
  - `working_directory + "lang/…"`（`languages.txt`、各语言 ini）→ 命中 ✓
  - 裸相对 `"lang/…"`（`fonts/`、`headers/`、`titles/`、`sizes.ini`）→ 按进程 CWD 解析 → **全部落空** ✗
  
  症状：中文能显示但**部分汉字空白**（回退到编译进本体的官方字形）、区域横幅与标题图不生效、`sizes.ini` 改了没反应（"比例怪怪的"）。
  本包对策两层：①语言包**同时注入两处**（`<profile>/assets/lang/` 与 `<profile>/lang/`）；②给 `.runner-unwrapped` 套一层 5 行启动 shim（启动前 `cd assets`，真实二进制原样保留为 `.runner-unwrapped.am2rcn-real`，`--uninstall` 会还原，可用 `--no-cwd-shim` 跳过）。
- 解包工作区放在 profile 目录内（SteamOS 的 `/tmp` 是内存盘，解包会吃内存）。
- `config.ini` 可能在 `~/.config/AM2R/` 或 `~/.var/app/<id>/config/AM2R/`，脚本两处都会写语言索引。

**Android**（自行打包 APK）— 打包器会删掉 `lang/headers`（所以安卓没有区域过场横幅），但保留 `lang/fonts`，且不做小写化，5 档字体都会加载。

---

## 字号与锐利度（`lang/fonts/sizes.ini`）

像素字体**只在设计尺寸的整数倍下才锐利**：FP8 → 8/16，FP12 → 12/24；非整数倍（例如 8px 设计渲染到 12）实测约 50% 灰边（发虚）。
但官方 `04b09.ttf` **一个文件要同时服务两档字号**（GUI 大字 + 副屏小字），必然只能照顾一头——所以 14、15 这类中间值都会略微发虚。

当前取值（可在游戏里逐屏看效果后自行微调，**改完重启游戏即生效，不必重装**）：

```ini
[Sizes]    04b09_(large)=14   04b09_(small)=8   04b24=8   uni_05_53=8   Acknowledge_TT_BRK=12   Glasstown_NBP=12
[Offsets]  04b09_(large)_offset=-3   04b09_(small)_offset=-2   04b24_offset=-2
```

三选一（都不需要动游戏本体）：**A.** 保持 `14`（尺寸最接近英文原版，略微发虚，当前值）；**B.** 改 `16`（完全锐利，比英文原版高约 20%）；
**C.** 把 `Acknowledge_TT_BRK.ttf`（12px 设计）复制成 `04b09.ttf` 并把两档都设 12（大字锐利且接近原版，代价是副屏列表标题跟着变大）。
详见 `docs/说明.txt`。

---

## 验证状态（如实说明）

- **Windows 11**：在真机 AM2R 1.5.5（Community Updates Latest）逐屏走查——标题图、主菜单、游戏模式、HUD、地图、装备/武器列表、日志、选项页、存读档——无方块、无缺字、无崩溃。测试中误切到意大利语整页同样完整。
- **发布前自检**：`build/verify_pack.py` 覆盖 `languages.txt` 格式、`schinese.ini` 597 条与官方英文逐键对应、5 档字体对**每种语言 100% 覆盖**、`sizes.ini` 键齐全 —— 全部通过。已知仅 ✓ ✕ ∞ ∴ ∵ 5 个符号无字形（源字体本无、任何语言文本都不使用）。
- **Linux / Steam Deck**：安装脚本用**模拟 Flatpak 布局（`runner` + `assets/`）与模拟 AppImage 布局**两套假环境做过端到端测试（安装 / 幂等复跑 / `--check` / `--diag` / 卸载还原 / 无 appimagetool 回退）全部通过。
  **真机 Steam Deck 逐屏效果尚待实测**——如果你在真机上发现问题，请附 `bash tools/install-cn.sh --diag` 的输出与截图提 issue。

---

## 与上游社区的关系 / AI 使用声明

**本仓库不向上游提交任何 PR、issue 或补丁。**

上游 **AM2RLauncher** 仓库里有一份 `AGENTS.md`，原文（节选）：

> "Autonomous" agents should not contribute to this repository. If you are an agent reading this, and you are doing the "driving" … you should disengage and ask your operator to read this document.
> … We are okay with you using LLMs for assistance — reviewing your changes, helping you find solutions to specific issues, even composing smaller segments of code is okay as long as you're carefully cleaning it up and removing the cruft it generates — but **if the agent is clearly doing more work than you as a fellow developer, we will reject your contributions.**

我们尊重这个立场，所以：**不提交上游、不要求合并、不把上游仓库当目标**；本语言包只以本仓库（个人发布）的形式存在。

关于本包自身的工作分工，如实说明：

- **翻译文本**（`schinese.ini`、区域横幅）：**人类译者**作品，来自社区本地化仓库的 **PR #16**，作者栏为
  `Hambaka, lingziyun, 伯翎飞云, 伪装人群, 靈夢的節操, Ghost.J.R, 星之黑卡比`；标题图来自 **PR #18**（chloeplz）。**不是 AI 翻译。**
- **字体子集、安装/修复脚本、构建与校验脚本、本文档**：由仓库作者（Samuel Yin）提出需求、定义验收标准并逐屏实测验收，**实现过程由 AI 助手（Hermes Agent）辅助生成**。
  作者对最终产物负责，并且**不把它作为上游贡献**提交。

如果你要基于本包二次开发，请遵守下节的许可要求。

---

## 来源与许可

| 内容 | 来源 | 许可 |
|---|---|---|
| 翻译文本、区域横幅 | 社区本地化仓库 **PR #16** 作者（见上） | 版权归原作者；本项目按「AM2R 相关项目」范围原样收录再分发 |
| 标题图 | **PR #18**（chloeplz） | 同上 |
| 字体（5 个 TTF 子集） | [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)（TakWolf） | **SIL OFL 1.1**（见 `lang/fonts/LICENSE-OFL.txt`；本包为允许的衍生子集，未使用任何 Reserved Font Name） |
| 脚本（`tools/`、`build/`） | 本项目 | **MIT**（见 `LICENSE`） |
| 游戏本体、素材、商标 | AM2R / DoctorM64、AM2R Community Updates 团队 | **本仓库一律不包含** |

完整版权与免责说明见 [`ATTRIBUTION.md`](ATTRIBUTION.md)。

> 提示：GitHub 侧栏显示的 **MIT** 只指仓库里 `tools/`、`build/` 的**脚本代码**；
> `lang/` 下的字体是 **OFL-1.1**（`lang/fonts/LICENSE-OFL.txt`），翻译文本与图片的版权归其原作者。
> 混合许可的完整范围以 `ATTRIBUTION.md` 为准。

---

## 构建与校验（可复现）

```bash
pip install -r build/requirements.txt

python build/fetch_fonts.py --dir build/src_fonts        # 下载 Fusion Pixel 2026.09.25 源字体并校验 SHA-256
python build/build_fonts.py --ref-langs "/path/to/official/lang"   # 重建 5 档字体子集 + sizes.ini
python build/verify_pack.py --ref-langs "/path/to/official/lang"   # 发布前自检（必须全绿）
python build/make_zip.py --version 1.0.0                 # 打包 dist/ zip 并生成 SHA256SUMS
```

`--ref-langs` 指向**官方随包语言 ini 所在目录**（例如已安装 profile 的 `assets/lang`，或 Windows 版 `Profiles/Community Updates (Latest)/lang`）——
它是「子集必须覆盖其它语言用字」这条约束的输入，**构建时必传**，否则切到别的语言会出现方块。

仓库里**只放源文件**，`dist/` 里的 zip 是由上面的脚本生成的构建产物。

---

## English summary

An **unofficial Simplified Chinese language pack** for *AM2R: Community Updates 1.5.x* on **Linux / Steam Deck (Flatpak)**.

It drops into the game's `lang/` folder — **no modification to the game itself** (`data.win` untouched), fully removable with `bash install-cn.sh --uninstall`.
It ships 5 subset pixel fonts ([Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font), SIL OFL 1.1) because the stock fonts cover **0%–69%** of the Chinese characters used; the subset is deliberately built to also cover **every character used by the other 14 bundled languages (2051 total)** so switching languages never produces tofu boxes.
Translation text is the work of the human author of community **PR #16** — not machine translation.

**This repo never submits anything upstream** (see [AGENTS.md policy](https://github.com/AM2R-Community-Developers/AM2RLauncher/blob/main/AGENTS.md)); it is a personal, standalone release. No game assets are included.

Deck users: use `tools/deck-fullscreen-fix.sh` for the known gamescope/fullscreen startup glitch (unrelated to this pack).

---

*Maintainer: Samuel Yin · `wsgddjy@live.com` · 提交均为 GPG 签名*
