# es3d-l10n

[English](README.md) | [中文](README.zh_cn.md)

[**Бесконечное лето 3D**](https://boosty.to/everlastingsummer3d)（《永恒之夏 3D》）本地化工具链。它可以解包游戏的 UE5 资源，让你在纯文本 CSV 文件中翻译提取出的文本，再将所有内容重新打包成可安装的 mod。全程无需 Unreal Engine 正式开发工具的参与。

**已测试的游戏版本：** `v0.5.0` 与 `v0.4.6.1`（UE 5.5）

---

## 目录

- [环境要求](#环境要求)
- [获取工具链](#获取工具链)
- [配置环境](#配置环境)
- [构建并安装翻译](#构建并安装翻译)
- [维护已有 mod](#维护已有-mod)
- [创建全新 mod](#创建全新-mod)
- [已包含的 mod](#已包含的-mod)
- [清理](#清理)
- [项目结构](#项目结构)
- [环境变量](#环境变量)
- [致谢](#致谢)

---

## 环境要求

| 要求 | 说明 |
|---|---|
| Windows | 本工具链基于 PowerShell |
| [PowerShell](https://learn.microsoft.com/powershell/) | Windows 自带 |
| [Git](https://git-scm.com/) + [Git LFS](https://git-lfs.com/) | 用于克隆本仓库 |
| *Бесконечное лето 3D* | 游戏本体——需自行准备，不包含在本仓库中 |

---

## 获取工具链

克隆仓库并拉取由 Git LFS 管理的大文件：

```powershell
git lfs install
git clone https://github.com/NewComer00/es3d-l10n.git
cd es3d-l10n
git lfs pull
```

然后将你的游戏文件夹复制或移动到本仓库**内部**，与工具链文件放在同一层：

```
es3d-l10n/                              ← 工具链（本仓库）
└── Бесконечное лето 3D.v0.5.0/         ← 游戏
```

> 工具链会自动检测游戏文件夹。如果自动检测失败，请参见 [`GAME_DIR`](#环境变量)。

---

## 配置环境

**a) 激活 Python 环境。** 这一步会安装 Python、[`just`](https://github.com/casey/just) 命令行工具，以及其他所需组件：

```powershell
. .\bootstrap.ps1
```

**b) 下载 Unreal Engine 相关工具**（解包器、资源转换器等）：

```powershell
just fetch-tools
```

**c) 提取游戏的加密密钥与映射文件。** 这些文件让工具链能够读取游戏资源，且会被缓存，每个游戏版本只需提取一次：

```powershell
just extract-aes-key
just extract-usmap
```

提取结果会缓存在 `.es3d/<hash>/` 下，只要游戏版本不变就会自动复用。

**遇到问题？随时查看帮助：**

```powershell
just help              # 通用帮助
just mod help          # mod 级命令帮助
just mod-locale help   # locale 级命令帮助
```

---

## 构建并安装翻译

每次开启新的工作会话时，先激活环境：

```powershell
. .\.venv\Scripts\Activate.ps1
# （也可以继续使用：. .\bootstrap.ps1）
```

**构建（build）** 会将翻译打包进可分发的文件夹。此命令会把指定语言（例如 `zh_cn`）的所有 mod 及 UE4SS 一并打包进 `dist/<locale>/`：

```powershell
just build-dist zh_cn
```

> 如果某个 mod 在 `build/<mod>/<locale>/locale.csv` 已有进行中的翻译，会优先使用它；否则工具链会从 `mods/.../locale.csv` 中已冻结的预翻译版本重新生成。

**安装（install）** 会直接将构建结果复制进你的游戏目录：

```powershell
just install-dist zh_cn
```

（如果 `dist/<locale>` 尚为空，此命令会自动先执行构建。你也可以手动将 `dist/zh_cn/*` 复制到 `Everlasting_summer.exe` 所在目录。）

生成的 `dist/<locale>/` 文件夹结构与游戏目录一致：

```
dist/zh_cn/Everlasting_summer/
  Content/Paks/mod_*_zh_cn_P.pak
  Binaries/Win64/dwmapi.dll
  Binaries/Win64/ue4ss/…
```

---

## 维护已有 mod

游戏中每一块可翻译的内容（UI、对话、配音字幕等）都对应一个独立的 **mod**。以维护已有的 `voice_prolog` 为例，将其预翻译文本转换为可安装的 pak 文件：

```powershell
just mod-locale voice_prolog zh_cn seed-locale
just mod-locale voice_prolog zh_cn build-pak
```

执行后会生成 `dist/zh_cn/Everlasting_summer/Content/Paks/mod_voice_prolog_zh_cn_P.pak`。

### 整个流程是如何衔接的

| 层级 | 步骤 | 作用 | 命令 |
|---|---|---|---|
| Mod | 解包 | 从游戏 PAK 中提取原始资源文件 | `just mod NAME unpack` |
| Mod | 转换 | 将二进制 UAsset 转换为可读的 JSON | `just mod NAME tojson` |
| Locale | 准备 | 获取可翻译字符串的 CSV，可来自冻结归档，也可从 JSON 重新提取 | `seed-locale` 或 `extract-csv` |
| Locale | 审阅 | 对比两份 CSV（例如新旧版本） | `diff-locale` |
| Locale | 完成 | 将翻译写回资源并重新打包 | `build-pak`（依次执行 `apply` → `fromjson` → `strip` → `pack`） |

需要 JSON 的命令（`extract-csv`、`apply`、`build-pak` 等）在发现 `build/<mod>/json/` 不存在时，会自动帮你执行 `just mod NAME tojson`。

> **游戏更新到新版本或打了补丁后**，请删除 `build/<mod>/`（或重新运行 `tojson`），以确保提取出的字符串与新版本游戏文件相匹配。

### 每个 locale 都有两份 CSV

| 文件 | 作用 |
|---|---|
| `mods/<mod>/<locale>/locale.csv` | 已冻结的归档参考翻译 |
| `build/<mod>/<locale>/locale.csv` | 你正在使用的工作副本——`apply` 和 `build-dist` 实际读取的就是它 |

部分 mod 除文本外还有额外步骤（字体、贴图、对话侧车文件等），请查阅该 mod 自己的 README。

---

## 创建全新 mod

**1. 按以下结构在 `mods/<name>/` 下建立文件：**

```
mods/my_mod/justfile
mods/my_mod/README.md           ← 该 mod 的说明文档
mods/my_mod/zh_cn/justfile
mods/my_mod/zh_cn/locale.csv    ← 可选；首次执行 extract-csv 后再添加
```

**2. 编写 mod 配置** —— `mods/my_mod/justfile`：

```just
import '../justfile'

mod := "my_mod"
unpack_paths := ["Everlasting_summer/Content/main/your/pak/path"]
tojson_exclude := ["*LipSyncSequence.uasset"]
uexp_signatures := ["0d02", "0d04", "1606"]
```

**3. 编写 locale 配置** —— `mods/my_mod/zh_cn/justfile`：

```just
import '../justfile'
import '../../locale.just'

locale := "zh_cn"
locale_dir := justfile_directory()
```

**4. 运行流程：**

```powershell
just mod-locale my_mod zh_cn extract-csv
# 编辑 build/my_mod/zh_cn/locale.csv，填入翻译内容
just mod-locale my_mod zh_cn build-pak
```

**5. 翻译完成后，将其冻结**：把工作副本复制回归档位置，使其成为新的默认版本：

```
build/my_mod/zh_cn/locale.csv  →  mods/my_mod/zh_cn/locale.csv
```

---

## 已包含的 mod

| Mod | 内容 |
|---|---|
| [`ui`](mods/ui/README.md) | HUD 与菜单（字体 + 贴图） |
| [`dialogs`](mods/dialogs/README.md) | 游戏内对话系统 |
| [`voice_prolog`](mods/voice_prolog/README.md) | 序章配音字幕 |
| [`voice_day_1`](mods/voice_day_1/README.md) | 第 1 天配音字幕 |
| [`voice_day_2`](mods/voice_day_2/README.md) | 第 2 天配音字幕 |
| [`voice_day_3`](mods/voice_day_3/README.md) | 第 3 天配音字幕 |
| [`voice_day_4`](mods/voice_day_4/README.md) | 第 4 天配音字幕 |
| [`voice_day_5`](mods/voice_day_5/README.md) | 第 5 天配音字幕 |
| [`ue4ss`](ue4ss/README.md) | 运行时 Lua 修复（中文 UI、光照、背景音乐） |

---

## 清理

```powershell
just clean-build     # 删除 build/
just clean-dist      # 删除 dist/
just clean-tools     # 删除 tools/（保留 .gitkeep）
just clean           # 以上全部，外加各 mod 的额外清理项
just mod ui clean    # 只清理单个 mod（build/ui 及其额外文件）
```

各 mod 可以在 `mods/<name>/justfile` 中通过 `_clean-extra` 定义自己的额外清理逻辑（例如 `ui` 和 `dialogs` 还会清除生成的 `zh_cn/assets/` 文件夹）。

---

## 项目结构

```
es3d-l10n/                              ← 工具链（本仓库）
├── mods/          pak 配方 + locale CSV（附各 mod 的 README）
├── ue4ss/         运行时 Lua mod，按语言分文件夹
├── build/         工作文件（已加入 gitignore）
├── dist/          可安装输出，按语言分文件夹（已加入 gitignore）
├── scripts/       Python 辅助脚本
├── tools/         固定版本的工具二进制文件（已加入 gitignore）
└── Бесконечное лето 3D.v0.5.0/         ← 游戏（已加入 gitignore，自动检测）
    └── Everlasting_summer.exe
        └── Everlasting_summer/Content/Paks/
```

| 文件夹 | 内容 |
|---|---|
| `mods/` | pak 配方、已冻结的翻译 CSV、各 mod 的 README |
| `ue4ss/` | UE4SS Lua 覆盖层，按语言分类 |
| `build/` | 提取出的资源、JSON、你正在编辑的工作 CSV |
| `dist/` | 可直接安装的 `dist/<locale>/Everlasting_summer/…` |
| `.es3d/<hash>/` | 按游戏版本缓存的数据（`aes.key`、`output.usmap`） |
| `tools/` | 由 `fetch-tools` / `fetch-ue4ss` 下载的固定版本工具 |

**辅助脚本**（`scripts/`）：`convert.py`、`extract_to_csv.py`、`apply_translations.py`、`strip_assets.py`、`diff_locale_csv.py`、`scale_font_upem.py`、`inject_ui_textures.py`

---

## 环境变量

| 变量 | 作用 |
|---|---|
| `GAME_DIR` | 当自动检测游戏文件夹失败时手动指定 |
| `ES3D_ROOT` | 覆盖仓库根目录路径 |
| `AES_KEY` | 覆盖已缓存的 AES 密钥 |
| `ES3D_DIFF` | `diff-locale` 使用的编辑器（`cursor`、`code`、`codium`） |
| `ES3D_UE4SS_URL` | 指定固定的 UE4SS 下载地址，跳过 GitHub API 查询 |
| `GITHUB_TOKEN` / `GH_TOKEN` | 可选；用于提高 `fetch-ue4ss` 的 GitHub API 速率限制 |

部分 mod 还有各自专用的环境变量，请查阅对应 mod 的 README。

---

## 致谢

- **工具链** —— MIT 许可证（见 [LICENSE](LICENSE)）
- **归档的 `zh_cn` 翻译** —— 改编自 [Everlasting Summer](https://soviet.games/everlasting-summer/)（原版 Ren'Py 视觉小说）；额外资源的致谢详见各 mod 的 README