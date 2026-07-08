# es3d-l10n

Localization toolchain for [**Бесконечное лето 3D**](https://boosty.to/everlastingsummer3d): unpack → extract strings → translate → repack `.pak` mods.

**Requires:** Windows, PowerShell, game install nested under repo root:

```
es3d-l10n/                              ← toolchain (this repo)
├── mods/          recipes + locale CSV
├── build/         working tree (gitignored)
├── dist/          output .pak files (gitignored)
├── scripts/       Python helpers
└── Бесконечное лето 3D.v0.4.6.1/         ← game (gitignored, auto-detected)
    └── Everlasting_summer.exe
        └── Everlasting_summer/Content/Paks/
```

**Tested game version:** `v0.4.6.1` (UE 5.5)

---

## Setup (once)

```powershell
. .\bootstrap.ps1              # installs uv, Python, just; activates .venv
just fetch-tools
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
just help                   # root recipes
just mod help               # per-mod: unpack, tojson
just mod-locale help        # per-locale: apply, pack, …
```

---

## Build an existing mod

Example: prologue subtitles (`voice_prolog` / `zh_cn`).

```powershell
. .\.venv\Scripts\Activate.ps1

just mod voice_prolog unpack
just mod voice_prolog tojson
just mod-locale voice_prolog zh_cn seed-locale
just mod-locale voice_prolog zh_cn all
```

Install output: `dist/mod_voice_prolog_zh_cn_P.pak` → `Everlasting_summer/Content/Paks/`.

**With existing translations:** `seed-locale` copies archive CSV → build, then edit build CSV if needed.

**Fresh extract / game update:** use `extract-csv` instead of `seed-locale`.

---

## Create a new mod

1. Add files under `mods/<name>/`:

```
mods/my_mod/justfile
mods/my_mod/zh_cn/justfile
mods/my_mod/zh_cn/locale.csv    ← optional; add after first extract-csv
```

2. Mod config — `mods/my_mod/justfile`:

```just
import '../justfile'

mod := "my_mod"
unpack_include := "Everlasting_summer/Content/main/your/pak/path"
tojson_exclude := "*LipSyncSequence.uasset"
uexp_signatures := "0d02 0d04 1606"
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
. .\.venv\Scripts\Activate.ps1

just mod my_mod unpack
just mod my_mod tojson
just mod-locale my_mod zh_cn extract-csv
# edit build/my_mod/zh_cn/locale.csv
just mod-locale my_mod zh_cn all
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
| Apply → pack | `all` (or step through apply / fromjson / strip / pack) |

Locale steps need `build/<mod>/json/` only — they do not re-run `tojson` unless you ask.

**Locale CSV**

- `mods/<mod>/<locale>/locale.csv` — archive (reference)
- `build/<mod>/<locale>/locale.csv` — active (used by `apply`)

Archived Chinese translations (`mods/*/zh_cn/locale.csv`) are derived from the [Everlasting Summer](https://soviet.games/everlasting-summer/) Ren'Py VN.

---

## Credits

- **Toolchain** — MIT License (see [LICENSE](LICENSE))
- **Archived `zh_cn` translations** — derived from [Everlasting Summer](https://soviet.games/everlasting-summer/) (Ren'Py VN)

---

## Included mods

| Mod | PAK path |
|-----|----------|
| `voice_prolog` | `main/звуки/пролог` |
| `voice_day_1` | `main/звуки/озвучка_1_день` |
| `voice_day_2` | `main/звуки/озвучка_2_день` |
| `voice_day_3` | `main/звуки/озвучка_3_день` |
| `voice_day_4` | `main/звуки/озвучка_4_день` |

---

## Reference

**Directories**

| Path | Contents |
|------|----------|
| `mods/` | Recipes, frozen CSV, optional `assets/` |
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

**Scripts** (`scripts/`)

`convert.py` · `extract_to_csv.py` · `apply_translations.py` · `strip_assets.py` · `diff_locale_csv.py`
