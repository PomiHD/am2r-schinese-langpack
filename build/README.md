# build/ — 构建与校验（可复现）

```bash
pip install -r requirements.txt

python fetch_fonts.py --dir src_fonts                    # 1. 下载源字体并校验 SHA-256
python build_fonts.py  --ref-langs "/path/to/official/lang"   # 2. 重建 5 档字体子集 + sizes.ini
python verify_pack.py  --ref-langs "/path/to/official/lang"   # 3. 发布前自检（必须全绿）
python make_zip.py     --version 1.0.0                   # 4. 打包 dist/ zip + SHA256SUMS
```

`--ref-langs` 指向**官方随包语言 ini 所在目录**，例如：

- Steam Deck / Flatpak：`~/.var/app/io.github.am2r_community_developers.AM2RLauncher/data/AM2RLauncher/Profiles/Community Updates (Latest)/assets/lang`
- Windows：`…\Profiles\Community Updates (Latest)\lang`

它是「字体子集必须覆盖其它语言用字」这条约束的输入，**构建时必传**：不传则子集只含中文，切到别的语言会满屏方块。

（脚本兼容 Git-Bash 风格的 `/d/xxx` 路径，会自行转成 `D:/xxx`。）

## 为什么字体这一块这么麻烦

改 `build_fonts.py` 前请先读这四条，每一条都是踩过的坑：

1. **5 个文件名与大小写是游戏 GML 里写死的**（`04b09.ttf` / `04b24.ttf` / `uni_05_53.ttf` / `Acknowledge_TT_BRK.ttf` / `Glasstown_NBP.ttf`），
   不能改名、不能合并档位、不能只改一部分——它们被游戏用固定路径加载。
2. **这 5 个槽位是共享的**：它们原本是官方字体，被我们的子集替换后，**任何语言里出现子集没有的字符都会变成 ▯**。
   所以子集 = 本包中文 ∪ 官方其余 14 种语言用字 ∪ 符号表 = **2051 字符**。
3. **源字体 FP8 不含西里尔/希腊字母**，用同族 FP12 补字；两者 `unitsPerEm` 不同（800 vs 1200），
   必须先把缺字的那份**精确缩放**（1.5×，整数倍缩放、像素网格不变）再合并，否则 fontTools 的 Merger 会直接拒绝。
4. **像素字体只在设计尺寸的整数倍下才锐利**：FP8 → 8/16，FP12 → 12/24。
   因为 `04b09.ttf` 一个文件要同时服务「GUI 大字 16」和「副屏小字 8」两档，所以 `sizes.ini` 里 14 这类中间值必然略微发虚——
   这是取舍，不是 bug（详见 `docs/说明.txt` 的「为什么会有『有些字偏大/偏小』」）。

## 语言包数据文件的格式（别手改错）

`lang/languages.txt` 必须与官方文件**逐字节同格式**：**CRLF 行尾 + 末行不带换行符**，共 14 行
（官方 13 种 + `schinese.ini` 在末位 → 语言索引 = 13）。

游戏用的是 `file_text_read_string` + `file_text_readln`（`scripts/init_languages.gml`），
行尾要不就全 CRLF、要不就全 LF，**混用会让索引解析错位**；历史上"追加语言后游戏回到英文"就是这个原因。
另外 `lang/fonts/sizes.ini` 是 CRLF、`lang/schinese.ini` 带 UTF-8 BOM。

这些字节由 `.gitattributes` 的 `lang/** -text` 冻结（否则 Windows 的 `core.autocrlf` 会改写），
并由 `verify_pack.py` 逐项校验。

## 文件

| 文件 | 作用 |
|---|---|
| `fetch_fonts.py` | 下载 Fusion Pixel 2026.09.25 的两个 zh_hans TTF，校验 SHA-256（源字体不入库，约 10 MB） |
| `build_fonts.py` | 子集化 + 缺失字符用 FP12 补 + upem 对齐合并，输出 5 个 TTF 与 `sizes.ini` |
| `verify_pack.py` | 发布前自检：`languages.txt` 格式/索引、`schinese.ini` 597 条与官方英文逐键对应、5 档字体 100% 覆盖、`sizes.ini` 键齐全 |
| `make_zip.py` | 按发行布局打包 `dist/*.zip` 并写 `SHA256SUMS` |

## 复现性说明

`build_fonts.py` 的输出**与已发布字体字形等价**（同字符集、同字号下渲染逐像素一致）；
TTF 二进制哈希会因 `head.modified` 时间戳而不同，这是 fontTools 的正常行为，判定等价请看字形与渲染而非文件哈希。
