# ue4ss — runtime Lua mods (UE4SS)

Custom scripts overlay the [UE4SS experimental](https://github.com/UE4SS-RE/RE-UE4SS/releases) framework.
Install target: `Everlasting_summer/Binaries/Win64/` (not Content/Paks).

Sources are per locale: `ue4ss/<locale>/Mods/`.

## Mods (`zh_cn`)

| Mod | Purpose |
|-----|---------|
| `ChineseUIMod` | Runtime UI Chinese (settings, choices, bug report, …) |
| `LightingFixMod` | Fix dark interiors after load (auto + F8) |
| `BgmFixMod` | Fix missing BGM on first launch (no `setting.sav`) |

Enable/disable: edit `ue4ss/<locale>/Mods/mods.txt` (`1` / `0`).

## Build into dist/

```powershell
just fetch-ue4ss              # resolve experimental-latest zip via GitHub API → tools/ue4ss/
just ue4ss stage zh_cn        # uses ue4ss/zh_cn/Mods/
# → dist/zh_cn/Everlasting_summer/Binaries/Win64/{dwmapi.dll,ue4ss/}
```

Copy `dist/<locale>/*` into the game root (next to `Everlasting_summer.exe`), or:

```powershell
just install-dist zh_cn
```

Optional:
- `$env:ES3D_UE4SS_URL = 'https://.../UE4SS_v….zip'` — pin / skip API
- `$env:GITHUB_TOKEN` or `GH_TOKEN` — higher API rate limit

## Layout

| Path | Contents |
|------|----------|
| `ue4ss/<locale>/Mods/<Name>/` | Custom Lua (committed) |
| `ue4ss/<locale>/Mods/mods.txt` | Enable list (overlay) |
| `tools/ue4ss/` | Fetched framework (`dwmapi.dll` + `ue4ss/`) |

## Debug

After launch: `Everlasting_summer/Binaries/Win64/ue4ss/UE4SS.log` — look for `[ChineseUIMod]`, `[LightingFixMod]`, `[BgmFixMod]`.
