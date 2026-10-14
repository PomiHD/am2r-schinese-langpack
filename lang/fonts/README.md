# lang/fonts/ — 字体档位说明

这 5 个 `.ttf` 是游戏**写死路径加载**的字体槽位（文件名与大小写都不能改），
内容是开源像素字体 [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)（TakWolf, **SIL OFL 1.1**）的**简体字形子集**。

| 文件 | 游戏里的用途 | 源字体设计尺寸 | `sizes.ini` 当前值 |
|---|---|---|---|
| `04b09.ttf` | `fontGUI`(主菜单/存档位/物品提示) + `fontSubScr`(副屏列表标题) | FP **8px** | large `14` / small `8` |
| `04b24.ttf` | `fontMenuTiny`(装备/武器/靴子条目名) | FP **8px** | `8` |
| `uni_05_53.ttf` | `fontMenuSmall`(HUD / 地图 / 通知 / 日志页眉) | FP **8px** | `8` |
| `Acknowledge_TT_BRK.ttf` | `fontGUI2`(日志/选项标签/菜单标签) | FP **12px** | `12` |
| `Glasstown_NBP.ttf` | `fontMenuSmall2`(日志正文/过场文本/物品说明) | FP **12px** | `12` |

## 子集范围（重要）

**2051 字符** = 本包 `schinese.ini` 用字（1249）∪ 官方随包其它 14 种语言用字（1190）∪ 符号/假名/希腊字母表（373）。

这 5 个槽位是**共享的**：换掉官方字体后，任何语言里出现、而子集里没有的字符都会显示成 ▯。
所以子集必须覆盖所有随包语言，不能只覆盖中文。详见 `build/README.md`。

已知无字形的字符（源字体本身没有，且没有任何语言文本使用）：`✓ ✕ ∞ ∴ ∵`。

## 锐利度

像素字体**只在设计尺寸的整数倍下才锐利**：FP8 → 8 / 16，FP12 → 12 / 24。
非整数倍（如 8px 设计渲染到 12px）实测约 50% 灰边（发虚）。
`04b09.ttf` 一个文件要同时服务 16px 与 8px 两档，因此 `sizes.ini` 里的 14 属于「尺寸最接近英文原版、但略微发虚」的取舍；
改为 16 可完全锐利但会大一圈。详见 `docs/说明.txt`。

## 许可

`LICENSE-OFL.txt` 是 SIL Open Font License 1.1 全文（Fusion Pixel Font 的许可）。
这 5 个 TTF 是**衍生子集，仍以 OFL 分发**——不要把它们当作 MIT 代码使用，也不要单独出售。
该字体未声明 Reserved Font Name，因此子集沿用原始字体名符合 OFL。
