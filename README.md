# es3d-l10n

Localization toolchain for [**Бесконечное лето 3D**](https://boosty.to/everlastingsummer3d): unpack → extract strings → translate → repack `.pak` mods.

**Requires:**
- Windows, PowerShell
- [Git LFS](https://git-lfs.com/) — binary assets under mods (e.g. `*.dds`)
- Game install nested under repo root:

```
es3d-l10n/                              ← toolchain (this repo)
├── mods/          recipes + locale CSV (+ per-mod README)
├── build/         working tree (gitignored)
├── dist/          output .pak files (gitignored)
├── scripts/       Python helpers
└── Бесконечное лето 3D.v0.5.0/         ← game (gitignored, auto-detected)
    └── Everlasting_summer.exe
        └── Everlasting_summer/Content/Paks/
```

**Tested game versions:** `v0.5.0`, `v0.4.6.1` (UE 5.5)

Per-mod docs: [`mods/<name>/README.md`](mods/).

---

## Clone

```powershell
git lfs install                # once per machine
git clone https://github.com/NewComer00/es3d-l10n.git
cd es3d-l10n
git lfs pull                   # if clone was without LFS smudge
```

## Setup (once)

```powershell
. .\bootstrap.ps1              # installs uv, Python, just; activates .venv
just fetch-tools               # pinned tools (repak, jmap, UAssetGUI, UE4-DDS-Tools, …)
just extract-aes-key
just extract-usmap             # launches game briefly; cached under .es3d/<hash>/
```

## Each session

Activate `.venv` in every new PowerShell window before `just`:

```powershell
. .\.venv\Scripts\Activate.ps1
# or: . .\bootstrap.ps1
```

```powershell
just help                       # root recipes
just mod help                   # mod overview
just mod NAME                   # per-mod recipes (default)
just mod-locale help            # locale overview
just mod-locale NAME LOCALE     # per-locale recipes (default)
```

---

## Build an existing mod

```powershell
. .\.venv\Scripts\Activate.ps1

just mod-locale voice_prolog zh_cn seed-locale
just mod-locale voice_prolog zh_cn build-pak   # → dist/mod_voice_prolog_zh_cn_P.pak
```

Install output: `dist/mod_*_zh_cn_P.pak` → `Everlasting_summer/Content/Paks/`.

**With existing translations:** `seed-locale` copies archive CSV → build.

**Fresh extract / game update:** use `extract-csv` instead of `seed-locale`.

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

## Pipeline

**Mod level** (shared across locales):

| Step | Command |
|------|---------|
| Unpack PAK paths | `just mod NAME unpack` |
| UAsset → JSON | `just mod NAME tojson` |

**Locale level** (per mod + locale):

| Step | Command |
|------|---------|
| Prepare CSV | `seed-locale` or `extract-csv` |
| Compare CSVs | `diff-locale` |
| Apply → pack | `build-pak` (or step through apply / fromjson / strip / pack) |

Locale recipes that need JSON (`extract-csv`, `apply`, `build-pak`, …) auto-run `just mod NAME tojson` when `build/<mod>/json/` is missing (includes unpack). If you install a **new game version or patch** (new `Everlasting_summer-Windows.pak`), delete `build/<mod>/` or run `just mod NAME tojson` yourself so strings match the current game.

**Locale CSV**

- `mods/<mod>/<locale>/locale.csv` — archive (reference)
- `build/<mod>/<locale>/locale.csv` — active (used by `apply`)

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

---

## Credits

- **Toolchain** — MIT License (see [LICENSE](LICENSE))
- **Archived `zh_cn` translations** — derived from [Everlasting Summer](https://soviet.games/everlasting-summer/) (Ren'Py VN); see each mod README for extra assets

---

## Reference

**Directories**

| Path | Contents |
|------|----------|
| `mods/` | Recipes, frozen CSV, per-mod README |
| `build/` | Extracted assets, JSON, active CSV, intermediates |
| `dist/` | Output `.pak` files |
| `.es3d/<hash>/` | Per-game cache (`aes.key`, `output.usmap`) |
| `tools/` | Pinned binaries (`fetch-tools`) |

**Environment**

| Variable | Purpose |
|----------|---------|
| `GAME_DIR` | Game folder name if auto-detect fails |
| `ES3D_ROOT` | Repo root override |
| `AES_KEY` | Override cached AES key |
| `ES3D_DIFF` | Editor for `diff-locale` (`cursor`, `code`, `codium`) |

Mod-specific env vars: see that mod’s README.

**Scripts** (`scripts/`)

`convert.py` · `extract_to_csv.py` · `apply_translations.py` · `strip_assets.py` · `diff_locale_csv.py` · `scale_font_upem.py` · `inject_ui_textures.py`
