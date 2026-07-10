# dialogs

Dialog text (`DialogSystem`). Sidecar `main/bp` and `main/models/руф/skel/` pass through unchanged (excluded from `tojson`).

Output: `dist/zh_cn/Everlasting_summer/Content/Paks/mod_dialogs_zh_cn_P.pak`

## Build

```powershell
just mod-locale dialogs zh_cn seed-locale
just mod-locale dialogs zh_cn build-pak
```

## Unpack paths

- `Everlasting_summer/Content/DialogSystem/`
- `Everlasting_summer/Content/main/bp`
- `Everlasting_summer/Content/main/models/руф/skel/`

`tojson_exclude`: `**/main/*` (only DialogSystem strings are extracted).

`fromjson` runs with **1 worker** — parallel UAssetGUI often hits `EnumPropertyData.Write` NullReferenceException on DialogSystem assets.

Optional font sidecar: `zh_cn/assets/` (e.g. LXGW WenKai) is overlaid at strip if present.
