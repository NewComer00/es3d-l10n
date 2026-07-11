# es3d-l10n

A localization toolchain for [**Бесконечное лето 3D**](https://boosty.to/everlastingsummer3d) (*Everlasting Summer 3D*). It unpacks the game's UE5 assets, lets you translate the extracted text in a plain CSV file, and repacks everything into an installable mod — no Unreal Engine expertise required.

**Tested on:** game versions `v0.5.0` and `v0.4.6.1` (UE 5.5)

---

## Table of contents

- [What you need](#what-you-need)
- [Get the toolchain](#get-the-toolchain)
- [Set up your environment](#set-up-your-environment)
- [Build and install a translation](#build-and-install-a-translation)
- [Working on an existing mod](#working-on-an-existing-mod)
- [Creating a brand-new mod](#creating-a-brand-new-mod)
- [Included mods](#included-mods)
- [Cleaning up](#cleaning-up)
- [Project layout](#project-layout)
- [Environment variables](#environment-variables)
- [Credits](#credits)

---

## What you need

| Requirement | Notes |
|---|---|
| Windows | The toolchain is PowerShell-based |
| [PowerShell](https://learn.microsoft.com/powershell/) | Comes with Windows |
| [Git](https://git-scm.com/) + [Git LFS](https://git-lfs.com/) | For cloning this repo |
| *Бесконечное лето 3D* | The game itself — you provide this, it's not included |

---

## Get the toolchain

Clone the repo and pull the large files tracked by Git LFS:

```powershell
git lfs install
git clone https://github.com/NewComer00/es3d-l10n.git
cd es3d-l10n
git lfs pull
```

Now copy or place your game folder **inside** the repo, next to the toolchain files:

```
es3d-l10n/                              ← the toolchain (this repo)
└── Бесконечное лето 3D.v0.5.0/         ← the game
```

> The toolchain auto-detects the game folder. If detection fails, see [`GAME_DIR`](#environment-variables).

---

## Set up your environment

**a) Activate the Python environment.** This installs Python, the [`just`](https://github.com/casey/just) command runner, and everything else needed:

```powershell
. .\bootstrap.ps1
```

**b) Download the Unreal Engine tools** (unpacker, asset converter, etc.):

```powershell
just fetch-tools
```

**c) Extract the game's encryption key and mapping file.** These let the toolchain read the game's assets, and are cached so this only needs to happen once per game version:

```powershell
just extract-aes-key
just extract-usmap
```

The results are cached under `.es3d/<hash>/` and reused automatically until the game version changes.

**Need help at any point?**

```powershell
just help              # general help
just mod help          # help for mod-level commands
just mod-locale help   # help for locale-level commands
```

---

## Build and install a translation

Every time you start a new session, activate the environment first:

```powershell
. .\.venv\Scripts\Activate.ps1
# (or, you can still use: . .\bootstrap.ps1)
```

**Build** the translation into a distributable folder. This packs every mod for the chosen locale (e.g. `zh_cn`) plus UE4SS into `dist/<locale>/`:

```powershell
just build-dist zh_cn
```

> If a mod already has an in-progress translation at `build/<mod>/<locale>/locale.csv`, that's used. Otherwise, the toolchain seeds from the frozen, pre-translated CSV shipped in `mods/.../locale.csv`.

**Install** the build straight into your game folder:

```powershell
just install-dist zh_cn
```

(This builds the locale first automatically if `dist/<locale>` is still empty. Alternatively, just copy `dist/zh_cn/*` next to `Everlasting_summer.exe` yourself.)

The resulting `dist/<locale>/` folder mirrors the game's own folder structure:

```
dist/zh_cn/Everlasting_summer/
  Content/Paks/mod_*_zh_cn_P.pak
  Binaries/Win64/dwmapi.dll
  Binaries/Win64/ue4ss/…
```

---

## Working on an existing mod

Each translatable piece of the game (UI, dialogue, voice-over subtitles, etc.) is a separate **mod**. To pick up an existing one — say, `voice_prolog` — and turn its pre-translated text into an installable pak file:

```powershell
just mod-locale voice_prolog zh_cn seed-locale
just mod-locale voice_prolog zh_cn build-pak
```

This produces `dist/zh_cn/Everlasting_summer/Content/Paks/mod_voice_prolog_zh_cn_P.pak`.

### How the pipeline fits together

| Level | Step | What it does | Command |
|---|---|---|---|
| Mod | Unpack | Extract the raw asset files from the game's PAK | `just mod NAME unpack` |
| Mod | Convert | Turn binary UAssets into readable JSON | `just mod NAME tojson` |
| Locale | Prepare | Get a CSV of translatable strings, either from the frozen archive or freshly extracted from JSON | `seed-locale` or `extract-csv` |
| Locale | Review | Compare two CSVs (e.g. old vs. new) | `diff-locale` |
| Locale | Finish | Apply translations back into the assets and repack | `build-pak` (runs `apply` → `fromjson` → `strip` → `pack`) |

Commands that need JSON (`extract-csv`, `apply`, `build-pak`, …) will automatically run `just mod NAME tojson` for you if `build/<mod>/json/` doesn't exist yet.

> **After updating the game to a new version or patch**, delete `build/<mod>/` (or re-run `tojson`) so the extracted strings match the new game files.

### Two versions of each locale CSV

| File | Purpose |
|---|---|
| `mods/<mod>/<locale>/locale.csv` | The frozen, archived reference translation |
| `build/<mod>/<locale>/locale.csv` | Your active working copy — this is what `apply` and `build-dist` actually use |

Some mods have extra steps beyond text (fonts, textures, dialog sidecars). Check that mod's own README for details.

---

## Creating a brand-new mod

**1. Lay out the folder structure** under `mods/<name>/`:

```
mods/my_mod/justfile
mods/my_mod/README.md           ← your notes on this mod
mods/my_mod/zh_cn/justfile
mods/my_mod/zh_cn/locale.csv    ← optional; add once you've run extract-csv
```

**2. Write the mod config** — `mods/my_mod/justfile`:

```just
import '../justfile'

mod := "my_mod"
unpack_paths := ["Everlasting_summer/Content/main/your/pak/path"]
tojson_exclude := ["*LipSyncSequence.uasset"]
uexp_signatures := ["0d02", "0d04", "1606"]
```

**3. Write the locale config** — `mods/my_mod/zh_cn/justfile`:

```just
import '../justfile'
import '../../locale.just'

locale := "zh_cn"
locale_dir := justfile_directory()
```

**4. Run the pipeline:**

```powershell
just mod-locale my_mod zh_cn extract-csv
# edit build/my_mod/zh_cn/locale.csv with your translations
just mod-locale my_mod zh_cn build-pak
```

**5. When you're happy with the translation, freeze it** by copying it into the archive so it becomes the new default:

```
build/my_mod/zh_cn/locale.csv  →  mods/my_mod/zh_cn/locale.csv
```

---

## Included mods

| Mod | Covers |
|---|---|
| [`ui`](mods/ui/README.md) | HUD and menus (fonts + textures) |
| [`dialogs`](mods/dialogs/README.md) | The in-game dialogue system |
| [`voice_prolog`](mods/voice_prolog/README.md) | Prologue subtitles |
| [`voice_day_1`](mods/voice_day_1/README.md) | Day 1 subtitles |
| [`voice_day_2`](mods/voice_day_2/README.md) | Day 2 subtitles |
| [`voice_day_3`](mods/voice_day_3/README.md) | Day 3 subtitles |
| [`voice_day_4`](mods/voice_day_4/README.md) | Day 4 subtitles |
| [`voice_day_5`](mods/voice_day_5/README.md) | Day 5 subtitles |
| [`ue4ss`](ue4ss/README.md) | Runtime Lua fixes (Chinese UI, lighting, BGM) |

---

## Cleaning up

```powershell
just clean-build     # remove build/
just clean-dist      # remove dist/
just clean-tools     # remove tools/ (keeps .gitkeep)
just clean           # everything above, plus per-mod extras
just mod ui clean    # clean just one mod (build/ui + its extras)
```

Individual mods can define their own extra cleanup via `_clean-extra` in `mods/<name>/justfile` (e.g. `ui` and `dialogs` also clear their generated `zh_cn/assets/` folders).

---

## Project layout

```
es3d-l10n/                              ← the toolchain (this repo)
├── mods/          pak recipes + locale CSVs (+ per-mod README)
├── ue4ss/         runtime Lua mods, one folder per locale
├── build/         working files (gitignored)
├── dist/          installable output, one folder per locale (gitignored)
├── scripts/       Python helper scripts
├── tools/         pinned binaries (gitignored)
└── Бесконечное лето 3D.v0.5.0/         ← the game (gitignored, auto-detected)
    └── Everlasting_summer.exe
        └── Everlasting_summer/Content/Paks/
```

| Folder | Contains |
|---|---|
| `mods/` | Pak recipes, frozen translation CSVs, per-mod README |
| `ue4ss/` | UE4SS Lua overlay, per locale |
| `build/` | Extracted assets, JSON, your active working CSVs |
| `dist/` | Ready-to-install `dist/<locale>/Everlasting_summer/…` |
| `.es3d/<hash>/` | Cached per-game-version data (`aes.key`, `output.usmap`) |
| `tools/` | Pinned tool binaries fetched by `fetch-tools` / `fetch-ue4ss` |

**Helper scripts** (`scripts/`): `convert.py`, `extract_to_csv.py`, `apply_translations.py`, `strip_assets.py`, `diff_locale_csv.py`, `scale_font_upem.py`, `inject_ui_textures.py`

---

## Environment variables

| Variable | Purpose |
|---|---|
| `GAME_DIR` | Set this if auto-detecting the game folder fails |
| `ES3D_ROOT` | Override the repo root path |
| `AES_KEY` | Override the cached AES key |
| `ES3D_DIFF` | Editor used by `diff-locale` (`cursor`, `code`, `codium`) |
| `ES3D_UE4SS_URL` | Pin a specific UE4SS download URL, skipping the GitHub API |
| `GITHUB_TOKEN` / `GH_TOKEN` | Optional; raises the GitHub API rate limit for `fetch-ue4ss` |

Some mods also use their own environment variables — check that mod's README.

---

## Credits

- **Toolchain** — MIT License (see [LICENSE](LICENSE))
- **Archived `zh_cn` translations** — adapted from [Everlasting Summer](https://soviet.games/everlasting-summer/) (the original Ren'Py visual novel); see each mod's README for additional asset credits