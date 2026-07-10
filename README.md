# es3d-l10n

Localization toolchain for [**Бесконечное лето 3D**](https://boosty.to/everlastingsummer3d): unpack → extract strings → translate → repack `.pak` mods (+ UE4SS Lua overlays).

**Requires:** Windows, PowerShell, [Git LFS](https://git-lfs.com/) (binary assets under mods, e.g. `*.dds`), and the game nested under the repo root (auto-detected; see [Reference](#reference)).

**Tested game versions:** `v0.5.0`, `v0.4.6.1` (UE 5.5)

---

## Getting started

### Clone

```powershell
git lfs install                # once per machine
git clone https://github.com/NewComer00/es3d-l10n.git
cd es3d-l10n
git lfs pull                   # if clone was without LFS smudge
```

### Setup (once)

```powershell
. .\bootstrap.ps1              # installs uv, Python, just; activates .venv
just fetch-tools               # pinned tools (repak, jmap, UAssetGUI, UE4-DDS-Tools, …)
just extract-aes-key
just extract-usmap             # launches game briefly; cached under .es3d/<hash>/
```

### Each session

```powershell
. .\.venv\Scripts\Activate.ps1
# or: . .\bootstrap.ps1

just help                       # root recipes
just mod help / just mod NAME
just mod-locale help / just mod-locale NAME LOCALE
```

---

## Build & install

**Build** pak mods + UE4SS into `dist/<locale>/` (locale required).
Uses active `build/<mod>/<locale>/locale.csv` when present; otherwise seeds from archived `mods/.../locale.csv`:

```powershell
just build-dist zh_cn
# just build-dist all         # every locale under mods/*/
```

**Install** copies `dist/<locale>/Everlasting_summer/` into the current game.
Builds that locale first if `dist/<locale>` is empty:

```powershell
just install-dist zh_cn
# or copy dist/zh_cn/* next to Everlasting_summer.exe
```

`dist/<locale>/` mirrors the game tree:

```
dist/zh_cn/Everlasting_summer/
  Content/Paks/mod_*_zh_cn_P.pak
  Binaries/Win64/dwmapi.dll
  Binaries/Win64/ue4ss/…
```

UE4SS only: `just ue4ss stage zh_cn` — details in [`ue4ss/README.md`](ue4ss/README.md).

---

## Working on a mod

```powershell
just mod-locale voice_prolog zh_cn seed-locale   # or extract-csv after a game update
just mod-locale voice_prolog zh_cn build-pak
# → dist/zh_cn/Everlasting_summer/Content/Paks/mod_voice_prolog_zh_cn_P.pak
```

| Level | Step | Command |
|-------|------|---------|
| Mod | Unpack PAK paths | `just mod NAME unpack` |
| Mod | UAsset → JSON | `just mod NAME tojson` |
| Locale | Prepare CSV | `seed-locale` (from archive) or `extract-csv` (from json) |
| Locale | Compare CSVs | `diff-locale` |
| Locale | Apply → pack | `build-pak` (or apply / fromjson / strip / pack) |

Locale recipes that need JSON (`extract-csv`, `apply`, `build-pak`, …) auto-run `just mod NAME tojson` when `build/<mod>/json/` is missing. After a **new game version or patch**, delete `build/<mod>/` or re-run `tojson` so strings match.

**Locale CSV**

| Path | Role |
|------|------|
| `mods/<mod>/<locale>/locale.csv` | Archive (frozen reference) |
| `build/<mod>/<locale>/locale.csv` | Active (used by `apply` / `build-dist`) |

Mod-specific steps (UI fonts/textures, dialogs sidecars, …): see that mod’s README.

---

## Create a new mod

1. Add files under `mods/<name>/`:

```
mods/my_mod/justfile
mods/my_mod/README.md           ← mod-specific notes
mods/my_mod/zh_cn/justfile
mods/my_mod/zh_cn/locale.csv    ← optional; add after first extract-csv
```

2. Mod config — `mods/my_mod/justfile`:

```just
import '../justfile'

mod := "my_mod"
unpack_paths := ["Everlasting_summer/Content/main/your/pak/path"]
tojson_exclude := ["*LipSyncSequence.uasset"]
uexp_signatures := ["0d02", "0d04", "1606"]
```

3. Locale config — `mods/my_mod/zh_cn/justfile`:

```just
import '../justfile'
import '../../locale.just'

locale := "zh_cn"
locale_dir := justfile_directory()
```

4. Run pipeline:

```powershell
just mod-locale my_mod zh_cn extract-csv
# edit build/my_mod/zh_cn/locale.csv
just mod-locale my_mod zh_cn build-pak
```

When translations are ready, freeze: copy `build/.../locale.csv` → `mods/.../locale.csv`.

---

## Included mods

| Mod | README |
|-----|--------|
| [`ui`](mods/ui/README.md) | HUD / menus; fonts + textures |
| [`dialogs`](mods/dialogs/README.md) | DialogSystem (+ bp/skel sidecars) |
| [`voice_prolog`](mods/voice_prolog/README.md) | Prologue subtitles |
| [`voice_day_1`](mods/voice_day_1/README.md) | Day 1 subtitles |
| [`voice_day_2`](mods/voice_day_2/README.md) | Day 2 subtitles |
| [`voice_day_3`](mods/voice_day_3/README.md) | Day 3 subtitles |
| [`voice_day_4`](mods/voice_day_4/README.md) | Day 4 subtitles |
| [`voice_day_5`](mods/voice_day_5/README.md) | Day 5 subtitles |
| [`ue4ss`](ue4ss/README.md) | Runtime Lua (ChineseUI / lighting / BGM fixes) |

---

## Clean

```powershell
just clean-build     # build/
just clean-dist      # dist/
just clean-tools     # tools/ (keeps .gitkeep)
just clean           # all of the above + per-mod extras (= clean-all)
just mod ui clean    # one mod: build/ui + that mod’s _clean-extra
```

Mods override `_clean-extra` in `mods/<name>/justfile` (e.g. ui/dialogs clear generated `zh_cn/assets/`).

---

## Reference

```
es3d-l10n/                              ← toolchain (this repo)
├── mods/          pak recipes + locale CSV (+ per-mod README)
├── ue4ss/         runtime Lua mods per locale (`ue4ss/<lang>/Mods/`)
├── build/         working tree (gitignored)
├── dist/          installable trees per locale (gitignored)
├── scripts/       Python helpers
├── tools/         pinned binaries (gitignored)
└── Бесконечное лето 3D.v0.5.0/         ← game (gitignored, auto-detected)
    └── Everlasting_summer.exe
        └── Everlasting_summer/Content/Paks/
```

| Path | Contents |
|------|----------|
| `mods/` | Pak recipes, frozen CSV, per-mod README |
| `ue4ss/` | UE4SS Lua overlay per locale |
| `build/` | Extracted assets, JSON, active CSV, intermediates |
| `dist/` | `dist/<locale>/Everlasting_summer/…` |
| `.es3d/<hash>/` | Per-game cache (`aes.key`, `output.usmap`) |
| `tools/` | Pinned binaries (`fetch-tools`, `fetch-ue4ss`) |

| Variable | Purpose |
|----------|---------|
| `GAME_DIR` | Game folder name if auto-detect fails |
| `ES3D_ROOT` | Repo root override |
| `AES_KEY` | Override cached AES key |
| `ES3D_DIFF` | Editor for `diff-locale` (`cursor`, `code`, `codium`) |
| `ES3D_UE4SS_URL` | Optional pin for `fetch-ue4ss` (skip GitHub API) |
| `GITHUB_TOKEN` / `GH_TOKEN` | Optional; raises GitHub API rate limit for `fetch-ue4ss` |

Mod-specific env vars: see that mod’s README.

**Scripts** (`scripts/`): `convert.py` · `extract_to_csv.py` · `apply_translations.py` · `strip_assets.py` · `diff_locale_csv.py` · `scale_font_upem.py` · `inject_ui_textures.py`

---

## Credits

- **Toolchain** — MIT License (see [LICENSE](LICENSE))
- **Archived `zh_cn` translations** — derived from [Everlasting Summer](https://soviet.games/everlasting-summer/) (Ren'Py VN); see each mod README for extra assets
