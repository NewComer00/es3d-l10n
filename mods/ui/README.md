# ui

HUD / menus / widgets Chinese localization: **strings** + **fonts** + **translated textures**.

Output: `dist/mod_ui_zh_cn_P.pak`

## Build

Source `.dds` are in Git LFS (see root [README](../../README.md)). After clone: `git lfs pull`.

```powershell
just mod-locale ui zh_cn seed-locale    # or extract-csv after a game update
just mod-locale ui zh_cn build-pak
```

`build-pak` runs `_ensure-assets` (fonts + DDS inject), then overlays `zh_cn/assets/` after strip.

## Asset recipes

| Recipe | Purpose |
|--------|---------|
| `fetch-fonts` | Re-download Zpix + rebuild `12507`+ZhiMangXing → `assets/` |
| `inject-textures` | Inject DDS into stock uassets from the **current game** → `assets/` |
| `fetch-textures` | Force re-inject (`ES3D_FORCE_INJECT=1`) from `textures/` |

```powershell
just mod-locale ui zh_cn fetch-fonts
just mod-locale ui zh_cn inject-textures
just mod-locale ui zh_cn fetch-textures   # re-inject even if assets/ cached
```

`inject-textures` uses [UE4-DDS-Tools](https://github.com/NewComer00/UE4-DDS-Tools/tree/5.5) (`just fetch-tools` / `fetch-dds-tools`). Optional: `ES3D_UE4_DDS_TOOLS` = local tool folder to skip download.

To update a texture: replace the `.dds` under `zh_cn/textures/` (keep `manifest.json` paths), then `fetch-textures`.

## Layout

| Path | Contents |
|------|----------|
| `zh_cn/locale.csv` | Frozen UI strings |
| `zh_cn/textures/` | Source `.dds` (Git LFS) + `manifest.json` |
| `zh_cn/assets/` | Pack overlay: `.ufont` + injected `.uasset/.uexp/.ubulk` |

Raw DDS stay under `textures/`. `assets/` holds **finished** overlays (not raw DDS). Strip copies translated widgets only, then overlays `assets/` into `stripped_uasset` before pack.

## Unpack paths

See `justfile`: `main/hud`, ColorPicker, InteractionWidgets, StoryAdvTemplate, ProIconPack, LSS loading UI (textures/fonts excluded from `tojson`).

## Environment

| Variable | Purpose |
|----------|---------|
| `ES3D_UE4_DDS_TOOLS` | Optional local UE4-DDS-Tools install (skip download) |
| `ES3D_FORCE_INJECT` | `1` = re-inject even if `assets/` cached |

## Credits

- [Zpix](https://github.com/SolidZORO/zpix-pixel-font), [Zhi Mang Xing](https://github.com/google/fonts/tree/main/ofl/zhimangxing)
- [UE4-DDS-Tools (5.5)](https://github.com/NewComer00/UE4-DDS-Tools/tree/5.5)
