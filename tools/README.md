# tools/ — 安装与显示修复脚本

两个脚本都**不修改游戏本体**（不碰 `data.win`），只操作 `lang/` 目录与游戏自己的 `config.ini`，并且都可以一键还原。

## `install-cn.sh` — 语言包安装器

```bash
bash install-cn.sh              # 安装（自动识别 Flatpak / AppImage / 普通目录三种布局）
bash install-cn.sh --check      # 只看现状，不改任何文件
bash install-cn.sh --diag       # 打印探测到的目录结构（排错时把它贴出来）
bash install-cn.sh --uninstall  # 卸载：被覆盖的文件按快照还原、新增文件删除
bash install-cn.sh --profile "Community Updates (Latest)"   # 只处理指定 profile
bash install-cn.sh --no-repack  # 仅 AppImage 布局：不重新打包，直接跑解包后的 AppRun
bash install-cn.sh --no-cwd-shim  # 不装「启动前切工作目录」的 shim
```

- 脚本从**自身所在目录**找语言包：发行 zip 里是 `./langpack/lang`，本仓库里是 `../lang`（两种布局都支持）。
- **幂等**：可重复执行，无副作用；安装时在 `lang/` 留下 `.am2rcn_added` / `.am2rcn_backup` 两个记账文件，卸载时自动清理。
- Flatpak（Steam Deck）布局下会做三件事，都是为了绕开「Launcher 把工作目录设成 profile 根、而数据在 `assets/`」这个坑：
  1. 语言包**双位置注入**：`<profile>/assets/lang/` 与 `<profile>/lang/`；
  2. 给 `<profile>/.runner-unwrapped` 套一层 5 行启动 shim（启动前 `cd assets`；真实二进制保留为 `.runner-unwrapped.am2rcn-real`）；
  3. 从大写字体文件**派生小写别名**（Linux 上 Launcher 会小写化文件名，而 GML 里写死的是大写名）。
- **更新/重装 profile 后要重跑**（Launcher 会覆盖 `lang/`，Flatpak 版连 `assets/` 一起覆盖）。

## `deck-fullscreen-fix.sh` — Steam Deck 全屏画面错乱修复

```bash
bash deck-fullscreen-fix.sh            # 应用：Fullscreen=0、窗口缩放=3x（改前先备份）
bash deck-fullscreen-fix.sh --check    # 只看当前设置
bash deck-fullscreen-fix.sh --restore  # 还原到修复前
```

改的是游戏的 `config.ini`（`Language` / `VSync` / 音量等其它设置一行不动）。脚本之外还需在 Deck 上手动两步：
**以掌机模式启动**（作为非 Steam 游戏加入），并在 `[···] → 性能菜单 → 当前游戏` 里设 **缩放模式=整数、缩放滤镜=像素**。
原理与更多排错见仓库 README 的「Steam Deck：掌机模式全屏画面错乱」一节和 `docs/说明.txt`。
