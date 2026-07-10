# es3d-l10n — Бесконечное лето 3D localization toolchain

set unstable
set lists
set allow-duplicate-recipes
set allow-duplicate-variables

set shell := ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
set windows-shell := ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

# --- pinned tool versions ---
repak_version := "0.2.3"
jmap_version := "0.1.1"
uassetgui_version := "1.1.0"
oodle_version := "v0.2.3-files"
aes_key_finder_commit := "00a5278c325e6ba70a3067d1f81f29e5583d5cf1"
# UE4-DDS-Tools (UE 5.5 fork) — inject translated DDS into stock uassets
# Prefer branch zip (stable). Optional GUI zip / local copy via ES3D_UE4_DDS_TOOLS.
ue4_dds_tools_url := "https://github.com/NewComer00/UE4-DDS-Tools/archive/refs/heads/5.5.zip"
ue4_dds_tools_gui_url := "https://github.com/NewComer00/UE4-DDS-Tools/releases/download/untagged-cde1f87a711e5fb4dc4e/UE4-DDS-Tools-edd6c5f-GUI.zip"
ue4_dds_tools_tag := "5.5-src"
# UE4SS — runtime Lua host; zip resolved from GitHub release (not a pinned filename)
ue4ss_release := "experimental-latest"
ue4ss_release_api := "https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/" + ue4ss_release

# --- paths ---
# Repo root: walk up from entry justfile to pyproject.toml (works for nested mods/* justfiles).
_here := justfile_directory()
root := env_var_or_default("ES3D_ROOT", shell('[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $OutputEncoding = [Console]::OutputEncoding; $d = (Resolve-Path -LiteralPath "' + _here + '").Path; while ($true) { if (Test-Path -LiteralPath (Join-Path $d "pyproject.toml")) { Write-Output $d; break }; $parent = Split-Path -Path $d -Parent; if (-not $parent -or $parent -eq $d) { throw "repo root not found from ' + _here + '" }; $d = $parent }'))
tool_dir := root + "/tools"

uv := tool_dir + "/uv/uv.exe"
repak := tool_dir + "/repak/repak.exe"
jmap := tool_dir + "/jmap/jmap_dumper.exe"
uassetgui := tool_dir + "/UAssetGUI/UAssetGUI.exe"
oodle_dll := tool_dir + "/repak/oo2core_9_win64.dll"
aes_key_finder := tool_dir + "/aes-key-finder/Find_AES_Key.bat"
ue4_dds_tools := tool_dir + "/ue4-dds-tools"
# Embedded python from GUI zip if present; else empty (inject uses uv run python).
ue4_dds_tools_py := ue4_dds_tools + "/python/python.exe"
ue4_dds_tools_main := ue4_dds_tools + "/src/main.py"
ue4ss_tools := tool_dir + "/ue4ss"

game_dir := env_var_or_default("GAME_DIR", shell('[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $OutputEncoding = [Console]::OutputEncoding; Set-Location -LiteralPath "' + root + '"; $glob = "Бесконечное лето 3D*"; $matches = @(Get-ChildItem -Directory -Path $glob -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "Everlasting_summer.exe") }); if ($matches.Count -eq 0) { throw "Game not found under ' + root + '. Install game or set GAME_DIR / just --set game_dir." }; if ($matches.Count -gt 1) { throw ("Multiple game installs: " + ($matches.Name -join ", ") + ". Set GAME_DIR or just --set game_dir.") }; $matches[0].Name'))
game_root := root + "/" + game_dir
game_pak := game_root + "/Everlasting_summer/Content/Paks/Everlasting_summer-Windows.pak"
game_paks_dir := game_root + "/Everlasting_summer/Content/Paks"
game_exe := game_root + "/Everlasting_summer.exe"
game_shipping_exe := game_root + "/Everlasting_summer/Binaries/Win64/Everlasting_summer-Win64-Shipping.exe"
game_win64_dir := game_root + "/Everlasting_summer/Binaries/Win64"

ue_version := shell('$vi = (Get-Item -LiteralPath "' + game_shipping_exe + '").VersionInfo; "VER_UE$($vi.FileMajorPart)_$($vi.FileMinorPart)"')

es3d_cache_root := root + "/.es3d"
game_cache_id := shell('[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $OutputEncoding = [Console]::OutputEncoding; $p = "' + game_shipping_exe + '"; if (-not (Test-Path -LiteralPath $p)) { throw "Game binary not found: $p" }; $sha = [System.Security.Cryptography.SHA256]::Create(); try { $fs = [System.IO.File]::OpenRead($p); $bytes = $sha.ComputeHash($fs); $fs.Close() } finally { $sha.Dispose() }; Write-Output ([BitConverter]::ToString($bytes).Replace("-", "").ToLower().Substring(0, 32))')
es3d_dir := es3d_cache_root + "/" + game_cache_id
mods_dir := root + "/mods"
build_dir := root + "/build"
dist_dir := root + "/dist"
# dist/<locale>/ mirrors game root — copy dist/<locale>/* into the game folder

usmap := es3d_dir + "/output.usmap"
aes_key_file := es3d_dir + "/aes.key"
aes_key_fallback := "0x0df94cfc33f7cb8acb15b3267806a0bf728f002dc0363e310116ee88cc97aef3"
aes_key_loaded := shell('$f = "' + aes_key_file + '"; $d = "' + aes_key_fallback + '"; if (Test-Path -LiteralPath $f) { (Get-Content -LiteralPath $f -Raw).Trim() } else { $d }')
aes_key := env_var_or_default("AES_KEY", aes_key_loaded)

workers := `$env:NUMBER_OF_PROCESSORS`
just_exe := root + "/.venv/Scripts/just.exe"

default: help

[doc("Show recipe list and usage (default)")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
help:
    $ErrorActionPreference = 'Stop'
    $just = '{{just_exe}}'
    & $just '_help-intro'
    Write-Host ''
    & $just '--list'

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_help-intro:
    $mods = '{{mods_dir}}'

    function Write-Title($t) { Write-Host $t -ForegroundColor Cyan }
    function Write-Section($t) { Write-Host $t -ForegroundColor Yellow }
    function Write-Cmd($t) { Write-Host $t -ForegroundColor Green }
    function Write-Note($t) { Write-Host $t -ForegroundColor DarkGray }

    Write-Title 'es3d-l10n — Бесконечное лето 3D localization'
    Write-Note ('=' * 40)
    Write-Host ''

    Write-Section 'Setup (run once)'
    Write-Cmd '  . .\bootstrap.ps1'
    Write-Cmd '  just fetch-tools'
    Write-Cmd '  just extract-aes-key'
    Write-Cmd '  just extract-usmap'
    Write-Host ''

    Write-Section 'Each session'
    Write-Cmd '  . .\.venv\Scripts\Activate.ps1'
    Write-Note '      or: . .\bootstrap.ps1'
    Write-Host ''

    Write-Section 'Build a mod'
    Write-Cmd '  just mod help'
    Write-Cmd '  just mod-locale help'
    Write-Cmd '  just mod NAME'
    Write-Note '      unpack, tojson          (default: help)'
    Write-Cmd '  just mod NAME RECIPE'
    Write-Note '      run a mod recipe'
    Write-Cmd '  just mod-locale NAME LOCALE'
    Write-Note '      seed-locale, apply, build-pak, ...  (default: help)'
    Write-Cmd '  just mod-locale NAME LOCALE RECIPE'
    Write-Note '      run a locale recipe'
    Write-Cmd '  just ue4ss stage LOCALE'
    Write-Note '      UE4SS + Lua → dist/LOCALE/.../Binaries/Win64/'
    Write-Cmd '  just build-dist LOCALE'
    Write-Note '      pak mods + ue4ss → dist/LOCALE/ (or all)'
    Write-Cmd '  just install-dist LOCALE'
    Write-Note '      copy dist/LOCALE/Everlasting_summer → game'
    Write-Cmd '  just clean / clean-all'
    Write-Note '      build + dist + tools + per-mod extras'
    Write-Host ''

    Write-Section 'Quick example — voice_prolog / zh_cn'
    Write-Cmd '  just mod voice_prolog unpack'
    Write-Note '      optional; tojson (auto from locale recipes) runs unpack'
    Write-Cmd '  just mod-locale voice_prolog zh_cn seed-locale'
    Write-Cmd '  just mod-locale voice_prolog zh_cn build-pak'
    Write-Note '      → dist/zh_cn/Everlasting_summer/Content/Paks/'
    Write-Host ''

    Write-Section 'Locale CSV'
    Write-Note '  mods/.../locale.csv    archive (reference only)'
    Write-Note '  build/.../locale.csv   active (used by apply)'
    Write-Host ''

    Write-Section 'Available mods'
    $found = $false
    Get-ChildItem -Path $mods -Directory | ForEach-Object {
        $found = $true
        $locales = @(Get-ChildItem -Path $_.FullName -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName 'justfile') } |
            ForEach-Object { $_.Name })
        $loc = if ($locales.Count) { $locales -join ', ' } else { '—' }
        Write-Host '  ' -NoNewline
        Write-Host $_.Name -ForegroundColor Cyan -NoNewline
        Write-Host '  [' -NoNewline -ForegroundColor DarkGray
        Write-Host $loc -NoNewline -ForegroundColor White
        Write-Host ']' -ForegroundColor DarkGray
    }
    if (-not $found) { Write-Note '  (none yet — add under mods/)' }
    Write-Note '  ue4ss/                 runtime Lua (just ue4ss stage)'

# --- setup ---

[doc("Download all pinned tools (repak, jmap, UAssetGUI, aes-key-finder, UE4-DDS-Tools)")]
fetch-tools:
    @Write-Host "[fetch-tools] installing pinned tools..."
    @just fetch-repak fetch-jmap fetch-uassetgui fetch-aes-key-finder fetch-dds-tools
    @Write-Host "[fetch-tools] done"

[doc("Download UE4-DDS-Tools (5.5) to tools/ue4-dds-tools/ for DDS inject/export")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
fetch-dds-tools:
    $ErrorActionPreference = 'Stop'
    $dest = '{{ue4_dds_tools}}'
    $marker = Join-Path $dest '.es3d-version'
    $main = '{{ue4_dds_tools_main}}'
    if ((Test-Path -LiteralPath $main) -and (Test-Path -LiteralPath $marker)) {
        $have = (Get-Content -LiteralPath $marker -Raw).Trim()
        if ($have -eq '{{ue4_dds_tools_tag}}') {
            Write-Host "[fetch-dds-tools] already installed: $dest ($have)"
            exit 0
        }
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installed = $false

    # 1) Local package via ES3D_UE4_DDS_TOOLS (optional)
    $local = $env:ES3D_UE4_DDS_TOOLS
    if ($local -and (Test-Path -LiteralPath (Join-Path $local 'src\main.py'))) {
        Write-Host "[fetch-dds-tools] copying ES3D_UE4_DDS_TOOLS -> $dest"
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $local -Destination $dest -Recurse -Force
        Set-Content -LiteralPath $marker -Value '{{ue4_dds_tools_tag}}' -NoNewline
        $installed = $true
    }

    # 2) Branch source zip (no embedded python — inject uses uv run python)
    if (-not $installed) {
        Write-Host "[fetch-dds-tools] downloading {{ue4_dds_tools_tag}}..."
        $zip = Join-Path $env:TEMP 'ue4-dds-tools.zip'
        $extract = Join-Path $env:TEMP 'ue4-dds-tools-extract'
        try {
            Invoke-WebRequest -Uri '{{ue4_dds_tools_url}}' -OutFile $zip -UseBasicParsing
            if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
            Expand-Archive -Path $zip -DestinationPath $extract -Force
            Remove-Item -LiteralPath $zip -Force
            $inner = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
            if (-not $inner) { throw "zip had no top-level folder" }
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Move-Item -LiteralPath $inner.FullName -Destination $dest
            Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
            Set-Content -LiteralPath $marker -Value '{{ue4_dds_tools_tag}}' -NoNewline
            $installed = $true
        } catch {
            Write-Host "[fetch-dds-tools] branch zip failed: $($_.Exception.Message)"
        }
    }

    # 3) Optional GUI release zip (may 404)
    if (-not $installed) {
        Write-Host "[fetch-dds-tools] trying GUI release zip..."
        $zip = Join-Path $env:TEMP 'ue4-dds-tools-gui.zip'
        $extract = Join-Path $env:TEMP 'ue4-dds-tools-gui-extract'
        try {
            Invoke-WebRequest -Uri '{{ue4_dds_tools_gui_url}}' -OutFile $zip -UseBasicParsing
            if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
            Expand-Archive -Path $zip -DestinationPath $extract -Force
            Remove-Item -LiteralPath $zip -Force
            $inner = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
            if (-not $inner) { $inner = Get-Item -LiteralPath $extract }
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            if (Test-Path -LiteralPath (Join-Path $inner.FullName 'src\main.py')) {
                Move-Item -LiteralPath $inner.FullName -Destination $dest
            } else {
                # zip root IS the tool
                New-Item -ItemType Directory -Force -Path $dest | Out-Null
                Copy-Item -Path (Join-Path $extract '*') -Destination $dest -Recurse -Force
            }
            Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
            Set-Content -LiteralPath $marker -Value '{{ue4_dds_tools_tag}}' -NoNewline
            $installed = $true
        } catch {
            Write-Host "[fetch-dds-tools] GUI zip failed: $($_.Exception.Message)"
        }
    }

    if (-not $installed -or -not (Test-Path -LiteralPath $main)) {
        throw "Failed to install UE4-DDS-Tools. Set ES3D_UE4_DDS_TOOLS to a local checkout/GUI folder, or check network access to GitHub."
    }
    Write-Host "[fetch-dds-tools] installed $dest"

[doc("Download UE4SS from experimental-latest release (resolves zip via GitHub API)")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
fetch-ue4ss:
    $ErrorActionPreference = 'Stop'
    $dest = '{{ue4ss_tools}}'
    $marker = Join-Path $dest '.es3d-version'
    $dll = Join-Path $dest 'ue4ss\UE4SS.dll'
    $dwmapi = Join-Path $dest 'dwmapi.dll'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Resolve download URL: ES3D_UE4SS_URL override, else GitHub API → UE4SS_v*.zip (not zDEV-)
    $url = $env:ES3D_UE4SS_URL
    $version = $null
    if ($url) {
        $version = [System.IO.Path]::GetFileName($url.Split('?')[0])
        Write-Host "[fetch-ue4ss] using ES3D_UE4SS_URL ($version)"
    } else {
        Write-Host "[fetch-ue4ss] resolving {{ue4ss_release}} via GitHub API..."
        $headers = @{ 'User-Agent' = 'es3d-l10n'; 'Accept' = 'application/vnd.github+json' }
        $token = $env:GITHUB_TOKEN; if (-not $token) { $token = $env:GH_TOKEN }
        if ($token) { $headers['Authorization'] = "Bearer $token" }
        try {
            $rel = Invoke-RestMethod -Uri '{{ue4ss_release_api}}' -Headers $headers
        } catch {
            if ((Test-Path -LiteralPath $dll) -and (Test-Path -LiteralPath $dwmapi)) {
                $have = if (Test-Path -LiteralPath $marker) { (Get-Content -LiteralPath $marker -Raw).Trim() } else { 'unknown' }
                Write-Host "[fetch-ue4ss] API failed ($($_.Exception.Message)); keeping cached install ($have)"
                Write-Host "[fetch-ue4ss] tip: set GITHUB_TOKEN / GH_TOKEN, or ES3D_UE4SS_URL to a direct zip URL"
                exit 0
            }
            throw "GitHub API failed and no cached UE4SS under $dest. Set ES3D_UE4SS_URL or GITHUB_TOKEN. $($_.Exception.Message)"
        }
        $asset = @($rel.assets) | Where-Object {
            $_.name -match '^UE4SS_v.*\.zip$' -and $_.name -notmatch '^zDEV-'
        } | Select-Object -First 1
        if (-not $asset) {
            $names = (@($rel.assets) | ForEach-Object { $_.name }) -join ', '
            throw "No UE4SS_v*.zip on release {{ue4ss_release}}. Assets: $names"
        }
        $url = $asset.browser_download_url
        $version = $asset.name
        Write-Host "[fetch-ue4ss] latest asset: $version"
    }

    if ((Test-Path -LiteralPath $dll) -and (Test-Path -LiteralPath $dwmapi) -and (Test-Path -LiteralPath $marker)) {
        $have = (Get-Content -LiteralPath $marker -Raw).Trim()
        if ($have -eq $version) {
            Write-Host "[fetch-ue4ss] already installed: $dest ($have)"
            exit 0
        }
        Write-Host "[fetch-ue4ss] outdated ($have -> $version), re-downloading..."
    }

    Write-Host "[fetch-ue4ss] downloading $version..."
    $zip = Join-Path $env:TEMP 'ue4ss-experimental.zip'
    $extract = Join-Path $env:TEMP 'ue4ss-experimental-extract'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    Remove-Item -LiteralPath $zip -Force
    # Zip root is dwmapi.dll + ue4ss/ (no extra top folder)
    $dwmapiSrc = Join-Path $extract 'dwmapi.dll'
    $ue4ssSrc = Join-Path $extract 'ue4ss'
    if (-not (Test-Path -LiteralPath $dwmapiSrc) -or -not (Test-Path -LiteralPath $ue4ssSrc)) {
        $inner = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
        if ($inner) {
            $dwmapiSrc = Join-Path $inner.FullName 'dwmapi.dll'
            $ue4ssSrc = Join-Path $inner.FullName 'ue4ss'
        }
    }
    if (-not (Test-Path -LiteralPath $dwmapiSrc)) { throw "dwmapi.dll not found in UE4SS zip" }
    if (-not (Test-Path -LiteralPath (Join-Path $ue4ssSrc 'UE4SS.dll'))) { throw "ue4ss/UE4SS.dll not found in UE4SS zip" }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -LiteralPath $dwmapiSrc -Destination (Join-Path $dest 'dwmapi.dll') -Force
    Copy-Item -LiteralPath $ue4ssSrc -Destination (Join-Path $dest 'ue4ss') -Recurse -Force
    Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    Set-Content -LiteralPath $marker -Value $version -NoNewline
    Write-Host "[fetch-ue4ss] installed $dest ($version)"

[doc("Copy dist/LOCALE into the game; builds that locale if dist is empty")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
install-dist LOCALE:
    $ErrorActionPreference = 'Stop'
    $locale = '{{LOCALE}}'.Trim()
    if (-not $locale) { throw "Usage: just install-dist <locale>   e.g. just install-dist zh_cn" }
    $src = Join-Path '{{dist_dir}}' "$locale\Everlasting_summer"
    $dst = Join-Path '{{game_root}}' 'Everlasting_summer'
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Host "[install-dist] dist/$locale empty — running: just build-dist $locale"
        & '{{just_exe}}' build-dist $locale
        if ($LASTEXITCODE -ne 0) { throw "build-dist failed with exit code $LASTEXITCODE" }
    }
    if (-not (Test-Path -LiteralPath $src)) {
        throw "Still nothing in dist/$locale after build-dist"
    }
    Write-Host "[install-dist] $src -> $dst"
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
    Write-Host "[install-dist] done"

[doc("Build pak mods + UE4SS into dist/LOCALE/; seed archive only if no active CSV")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
build-dist LOCALE:
    $ErrorActionPreference = 'Stop'
    $want = '{{LOCALE}}'.Trim()
    if (-not $want) { throw "Usage: just build-dist <locale|all>   e.g. just build-dist zh_cn" }
    $modsRoot = '{{mods_dir}}'
    $just = '{{just_exe}}'
    $built = 0
    $locales = [System.Collections.Generic.HashSet[string]]::new()
    Get-ChildItem -LiteralPath $modsRoot -Directory | Sort-Object Name | ForEach-Object {
        $modName = $_.Name
        if (-not (Test-Path -LiteralPath (Join-Path $_.FullName 'justfile'))) { return }
        Get-ChildItem -LiteralPath $_.FullName -Directory | Sort-Object Name | ForEach-Object {
            $locale = $_.Name
            if ($want -ne 'all' -and $locale -ne $want) { return }
            $localeJf = Join-Path $_.FullName 'justfile'
            $archive = Join-Path $_.FullName 'locale.csv'
            if (-not (Test-Path -LiteralPath $localeJf)) { return }
            if (-not (Test-Path -LiteralPath $archive)) {
                Write-Host "[build-dist] skip $modName/$locale (no locale.csv archive)"
                return
            }
            Write-Host "[build-dist] === $modName / $locale ==="
            $active = Join-Path '{{build_dir}}' "$modName\$locale\locale.csv"
            if (Test-Path -LiteralPath $active) {
                Write-Host "[build-dist] using active CSV: $active"
            } else {
                Write-Host "[build-dist] no active CSV — seeding from archive"
                & $just mod-locale $modName $locale seed-locale
                if ($LASTEXITCODE -ne 0) { throw "seed-locale failed: $modName/$locale (exit $LASTEXITCODE)" }
            }
            & $just mod-locale $modName $locale build-pak
            if ($LASTEXITCODE -ne 0) { throw "build-pak failed: $modName/$locale (exit $LASTEXITCODE)" }
            [void]$locales.Add($locale)
            $built++
        }
    }
    if ($built -eq 0) {
        throw "[build-dist] no pak mods built for locale='$want' (need mods/<name>/<locale>/locale.csv)"
    }
    foreach ($locale in ($locales | Sort-Object)) {
        Write-Host "[build-dist] staging UE4SS → dist/$locale/..."
        & $just ue4ss stage $locale
        if ($LASTEXITCODE -ne 0) { throw "ue4ss stage $locale failed (exit $LASTEXITCODE)" }
    }
    Write-Host "[build-dist] done: $built pak(s) + ue4ss → dist/($(($locales | Sort-Object) -join ', '))"
    if ($want -eq 'all') {
        Write-Host "[build-dist] install with: just install-dist <locale>"
    } else {
        Write-Host "[build-dist] install with: just install-dist $want"
    }

[doc("Remove build/")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
clean-build:
    $ErrorActionPreference = 'Stop'
    $dir = '{{build_dir}}'
    if (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force
        Write-Host "[clean-build] removed $dir"
    } else {
        Write-Host "[clean-build] nothing to remove"
    }

[doc("Remove dist/")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
clean-dist:
    $ErrorActionPreference = 'Stop'
    $dir = '{{dist_dir}}'
    if (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force
        Write-Host "[clean-dist] removed $dir"
    } else {
        Write-Host "[clean-dist] nothing to remove"
    }

[doc("Remove tools/ downloads (keeps tools/.gitkeep)")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
clean-tools:
    $ErrorActionPreference = 'Stop'
    $dir = '{{tool_dir}}'
    if (-not (Test-Path -LiteralPath $dir)) {
        Write-Host "[clean-tools] nothing to remove"
        exit 0
    }
    $n = 0
    Get-ChildItem -LiteralPath $dir -Force | Where-Object { $_.Name -ne '.gitkeep' } | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
        $n++
    }
    Write-Host "[clean-tools] removed $n item(s) under $dir"

[doc("Per-mod clean (build/MOD + _clean-extra) and ue4ss clean")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_clean-mods:
    $ErrorActionPreference = 'Stop'
    $just = '{{just_exe}}'
    $modsRoot = '{{mods_dir}}'
    Get-ChildItem -LiteralPath $modsRoot -Directory | Sort-Object Name | ForEach-Object {
        if (-not (Test-Path -LiteralPath (Join-Path $_.FullName 'justfile'))) { return }
        Write-Host "[clean] mod $($_.Name)"
        & $just mod $_.Name clean
        if ($LASTEXITCODE -ne 0) { throw "just mod $($_.Name) clean failed (exit $LASTEXITCODE)" }
    }
    $ue4ssJf = Join-Path '{{root}}' 'ue4ss\justfile'
    if (Test-Path -LiteralPath $ue4ssJf) {
        Write-Host "[clean] ue4ss"
        & $just ue4ss clean
        if ($LASTEXITCODE -ne 0) { throw "just ue4ss clean failed (exit $LASTEXITCODE)" }
    }

[doc("Clean build + dist + tools + per-mod extras")]
clean-all: _clean-mods clean-build clean-dist clean-tools
    @Write-Host "[clean-all] done"

[doc("Same as clean-all")]
clean: clean-all

[doc("UE4SS recipes: just ue4ss stage LOCALE | just ue4ss clean")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
ue4ss *ARGS:
    $ErrorActionPreference = 'Stop'
    $jf = Join-Path '{{root}}' 'ue4ss\justfile'
    if (-not (Test-Path -LiteralPath $jf)) { throw "Missing $jf" }
    $extra = '{{ARGS}}'.Trim()
    if (-not $extra) {
        throw "Usage: just ue4ss stage <locale> | just ue4ss clean"
    }
    $argList = @('-f', $jf)
    $argList += $extra -split '\s+'
    & '{{just_exe}}' @argList
    exit $LASTEXITCODE

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_fetch-repak:
    $ErrorActionPreference = 'Stop'
    $dest = '{{tool_dir}}/repak'
    $exe = Join-Path $dest 'repak.exe'
    if (Test-Path $exe) { Write-Host "[fetch-repak] already installed: $exe"; exit 0 }
    Write-Host "[fetch-repak] downloading v{{repak_version}}..."
    $url = 'https://github.com/trumank/repak/releases/download/v{{repak_version}}/repak_cli-x86_64-pc-windows-msvc.zip'
    $zip = Join-Path $env:TEMP 'repak_cli.zip'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip
    Write-Host "[fetch-repak] installed $exe"

[doc("Download repak CLI to tools/repak/ (includes oodle DLL)")]
fetch-repak: fetch-oodle

[doc("Download jmap_dumper to tools/jmap/")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
fetch-jmap:
    $ErrorActionPreference = 'Stop'
    $dest = '{{tool_dir}}/jmap'
    $exe = Join-Path $dest 'jmap_dumper.exe'
    if (Test-Path $exe) { Write-Host "[fetch-jmap] already installed: $exe"; exit 0 }
    Write-Host "[fetch-jmap] downloading v{{jmap_version}}..."
    $url = 'https://github.com/trumank/jmap/releases/download/v{{jmap_version}}/jmap_dumper-x86_64-pc-windows-msvc.zip'
    $zip = Join-Path $env:TEMP 'jmap_dumper.zip'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip
    Write-Host "[fetch-jmap] installed $exe"

[doc("Download UAssetGUI.exe to tools/UAssetGUI/")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
fetch-uassetgui:
    $ErrorActionPreference = 'Stop'
    $dest = '{{tool_dir}}/UAssetGUI'
    $exe = Join-Path $dest 'UAssetGUI.exe'
    if (Test-Path $exe) { Write-Host "[fetch-uassetgui] already installed: $exe"; exit 0 }
    Write-Host "[fetch-uassetgui] downloading v{{uassetgui_version}}..."
    $url = 'https://github.com/atenfyr/UAssetGUI/releases/download/v{{uassetgui_version}}/UAssetGUI.exe'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $exe
    Write-Host "[fetch-uassetgui] installed $exe"

[doc("Download oo2core_9_win64.dll to tools/repak/ (Oodle decompression)")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
fetch-oodle: _fetch-repak
    $ErrorActionPreference = 'Stop'
    $dest = '{{tool_dir}}/repak'
    $dll = Join-Path $dest 'oo2core_9_win64.dll'
    if (Test-Path $dll) { Write-Host "[fetch-oodle] already installed: $dll"; exit 0 }
    Write-Host "[fetch-oodle] downloading {{oodle_version}}..."
    $url = 'https://github.com/new-world-tools/go-oodle/releases/download/{{oodle_version}}/oo2core_9_win64.dll'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $dll
    Write-Host "[fetch-oodle] installed $dll"

[doc("Download AESKeyFinder + QuickBMS scripts to tools/aes-key-finder/")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
fetch-aes-key-finder:
    $ErrorActionPreference = 'Stop'
    $dest = '{{tool_dir}}/aes-key-finder'
    $bat = Join-Path $dest 'Find_AES_Key.bat'
    if (Test-Path $bat) { Write-Host "[fetch-aes-key-finder] already installed: $bat"; exit 0 }
    Write-Host "[fetch-aes-key-finder] downloading {{aes_key_finder_commit}}..."
    $commit = '{{aes_key_finder_commit}}'
    $url = "https://github.com/GHFear/AESKeyFinder-By-GHFear/archive/$commit.zip"
    $zip = Join-Path $env:TEMP 'aes-key-finder.zip'
    $extract = Join-Path $env:TEMP 'aes-key-finder-extract'
    Invoke-WebRequest -Uri $url -OutFile $zip
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $inner = Get-ChildItem -Path $extract -Directory | Select-Object -First 1
    $src = Join-Path $inner.FullName 'AES Key Finder 2.0 - By GHFear'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
    Remove-Item $zip -Force
    Remove-Item $extract -Recurse -Force
    Write-Host "[fetch-aes-key-finder] installed $bat"

# --- AES key (non-interactive; verified with repak; saved to aes.key) ---

[doc("Scan game exe for AES key, verify with repak, save to .es3d/<hash>/aes.key")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
extract-aes-key: fetch-aes-key-finder fetch-repak
    $ErrorActionPreference = 'Stop'
    Write-Host "[extract-aes-key] starting..."
    $finderDir = '{{tool_dir}}/aes-key-finder'
    $qbms = Join-Path $finderDir 'scripts\quickbms_4gb_files.exe'
    $repakExe = '{{repak}}'
    $pakPath = '{{game_pak}}'
    $keyFile = '{{aes_key_file}}'
    $shippingExe = '{{game_shipping_exe}}'

    function Normalize-AesKey([string]$Key) {
        if ($Key -match '^(?i)0x([0-9a-f]+)$') {
            $hex = $Matches[1].ToLower()
            if ($hex.Length -gt 64) { return $null }
            return '0x' + $hex.PadLeft(64, '0')
        }
        return $null
    }

    function Test-AesKey([string]$Key) {
        $normalized = Normalize-AesKey $Key
        if (-not $normalized) { return $false }
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $out = & $repakExe --aes-key $normalized info $pakPath 2>&1 | Out-String
            return ($LASTEXITCODE -eq 0) -and ($out -match 'file entries')
        } finally {
            $ErrorActionPreference = $prev
        }
    }

    if (-not (Test-Path -LiteralPath $shippingExe)) {
        throw "Shipping exe not found: $shippingExe"
    }
    if (-not (Test-Path -LiteralPath $pakPath)) {
        throw "PAK not found: $pakPath"
    }

    if (Test-Path -LiteralPath $keyFile) {
        $existing = (Get-Content -LiteralPath $keyFile -Raw).Trim()
        if ($existing -and (Test-AesKey $existing)) {
            Write-Host "[extract-aes-key] valid key already saved: $keyFile"
            Write-Host $existing
            exit 0
        }
        Write-Host "[extract-aes-key] existing key failed repak verification; rescanning..."
    }

    Push-Location $finderDir
    try {
        Get-ChildItem -Directory | Where-Object { $_.Name -ne 'scripts' } | Remove-Item -Recurse -Force
        Get-ChildItem -Filter '*.exe' | Remove-Item -Force
        Copy-Item -LiteralPath $shippingExe -Destination . -Force
        $gameExe = (Get-ChildItem -Filter '*.exe' | Select-Object -First 1).Name

        foreach ($script in @('findaes.bms', 'findaes2.bms', 'findaes3.bms')) {
            Write-Host "[extract-aes-key] scanning with $script (may take several minutes)..."
            & $qbms -q (Join-Path 'scripts' $script) $gameExe
        }

        $candidates = @(
            Get-ChildItem -Recurse -File |
                Where-Object { $_.Name -match '^0x[0-9A-Fa-f]+$' } |
                ForEach-Object { Normalize-AesKey $_.Name } |
                Where-Object { $_ }
        ) | Select-Object -Unique

        if (-not $candidates) {
            throw 'No valid AES key candidates found (need 0x + up to 64 hex digits).'
        }

        Write-Host "[extract-aes-key] found $($candidates.Count) candidate(s); verifying with repak..."
        foreach ($candidate in $candidates) {
            Write-Host "[extract-aes-key]   trying $candidate"
            if (Test-AesKey $candidate) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $keyFile) | Out-Null
                [System.IO.File]::WriteAllText($keyFile, $candidate)
                Write-Host "[extract-aes-key] verified key saved to $keyFile"
                Write-Host $candidate
                exit 0
            }
        }

        throw "No candidate decrypted $pakPath. Try AESDumpster or inspect QuickBMS output under $finderDir."
    } finally {
        Pop-Location
    }

# --- USMAP -> output.usmap ---
# Launches game via normal launcher, dumps shipping PID, then kills game.
# First run may show Windows SmartScreen/Firewall once — approve manually.

[doc("Launch game, dump USMAP mappings to .es3d/<hash>/output.usmap (skipped if exists)")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
extract-usmap wait='30': fetch-jmap
    $ErrorActionPreference = 'Stop'
    $usmap = '{{usmap}}'
    if (Test-Path -LiteralPath $usmap) {
        Write-Host "[extract-usmap] already cached: $usmap"
        exit 0
    }
    Write-Host "[extract-usmap] starting (warmup={{wait}}s)..."
    $launcherExe = '{{game_exe}}'
    $launcherName = [System.IO.Path]::GetFileNameWithoutExtension($launcherExe)
    $launcherDir = Split-Path -Parent $launcherExe
    $shippingName = [System.IO.Path]::GetFileNameWithoutExtension('{{game_shipping_exe}}')
    $jmap = '{{jmap}}'
    $warmupSec = [int]'{{wait}}'

    if (-not (Test-Path -LiteralPath $launcherExe)) {
        throw "Launcher not found: $launcherExe"
    }
    if (Get-Process -Name $shippingName -ErrorAction SilentlyContinue) {
        throw "Game already running ($shippingName). Close it first."
    }

    $launcher = Start-Process -FilePath $launcherExe -WorkingDirectory $launcherDir -PassThru
    Write-Host "[extract-usmap] started $launcherName (PID $($launcher.Id)); waiting for $shippingName..."

    try {
        $deadline = (Get-Date).AddSeconds(120)
        $game = $null
        while ((Get-Date) -lt $deadline) {
            $game = Get-Process -Name $shippingName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($game) { break }
            Start-Sleep -Seconds 1
        }
        if (-not $game) {
            throw "Timed out waiting for $shippingName (approve SmartScreen/Firewall if prompted)"
        }

        Write-Host "[extract-usmap] found $shippingName (PID $($game.Id))"

        if ($warmupSec -gt 0) {
            Write-Host "[extract-usmap] waiting ${warmupSec}s for game init..."
            Start-Sleep -Seconds $warmupSec
            $game = Get-Process -Name $shippingName -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $game) { throw "$shippingName exited during warmup" }
        }

        Write-Host "[extract-usmap] dumping USMAP from PID $($game.Id)..."
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $usmap) | Out-Null
        & $jmap --pid $game.Id $usmap
        if ($LASTEXITCODE -ne 0) { throw "jmap_dumper failed with exit code $LASTEXITCODE" }
        Write-Host "[extract-usmap] wrote $usmap"
    } finally {
        Write-Host "[extract-usmap] stopping game..."
        Get-Process -Name $shippingName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process -Name $launcherName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

# --- mod entrypoints (see mods/justfile + mods/<name>/) ---

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_help-mod name='':
    $mods = '{{mods_dir}}'
    $just = '{{just_exe}}'
    $name = '{{name}}'.Trim()

    function Write-Title($t) { Write-Host $t -ForegroundColor Cyan }
    function Write-Section($t) { Write-Host $t -ForegroundColor Yellow }
    function Write-Cmd($t) { Write-Host $t -ForegroundColor Green }
    function Write-Note($t) { Write-Host $t -ForegroundColor DarkGray }

    function Show-RecipeList($jf, [string[]]$names) {
        $header = $false
        & $just -f $jf '--list' | ForEach-Object {
            if ($_ -match '^\s+(\S+)') {
                if ($names -contains $Matches[1]) {
                    if (-not $header) {
                        Write-Host 'Available recipes:'
                        $header = $true
                    }
                    Write-Host $_
                }
            }
        }
        if (-not $header) { Write-Note '  (no recipes found)' }
    }

    Write-Title 'Mod recipes (shared per mod)'
    Write-Note ('=' * 40)
    Write-Host ''

    Write-Section 'Usage'
    Write-Cmd '  just mod help'
    Write-Note '      this overview'
    Write-Cmd '  just mod NAME'
    Write-Note '      recipes for one mod (default)'
    Write-Cmd '  just mod NAME RECIPE'
    Write-Note '      run a recipe (unpack, tojson, ...)'
    Write-Host ''

    Write-Section 'Pipeline'
    Write-Note '  unpack     repak extract → build/MOD/extracted/'
    Write-Note '  tojson     UAssetGUI → build/MOD/json/ (needs extract-usmap once)'
    Write-Note '  clean      build/MOD + optional _clean-extra'
    Write-Host ''

    if ($name) {
        $jf = Join-Path (Join-Path $mods $name) 'justfile'
        if (-not (Test-Path -LiteralPath $jf)) { throw "Mod not found: $name (expected $jf)" }
        Write-Section "Mod: $name"
        Write-Host ''
        Show-RecipeList $jf @('unpack', 'tojson', 'clean')
    } else {
        Write-Section 'Available mods'
        $found = $false
        Get-ChildItem -Path $mods -Directory | ForEach-Object {
            if (-not (Test-Path -LiteralPath (Join-Path $_.FullName 'justfile'))) { return }
            $found = $true
            Write-Host '  ' -NoNewline
            Write-Host $_.Name -ForegroundColor Cyan
        }
        if (-not $found) { Write-Note '  (none yet — add under mods/)' }
        Write-Host ''
        $exampleJf = Get-ChildItem -Path $mods -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'justfile') } |
            Select-Object -First 1 |
            ForEach-Object { Join-Path $_.FullName 'justfile' }
        if ($exampleJf) {
            Write-Section 'Recipe list (per mod; example)'
            Show-RecipeList $exampleJf @('unpack', 'tojson')
        }
    }

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_help-mod-locale name='' locale='':
    $mods = '{{mods_dir}}'
    $just = '{{just_exe}}'
    $name = '{{name}}'.Trim()
    $locale = '{{locale}}'.Trim()

    function Write-Title($t) { Write-Host $t -ForegroundColor Cyan }
    function Write-Section($t) { Write-Host $t -ForegroundColor Yellow }
    function Write-Cmd($t) { Write-Host $t -ForegroundColor Green }
    function Write-Note($t) { Write-Host $t -ForegroundColor DarkGray }

    function Show-RecipeList($jf, [string[]]$names) {
        $header = $false
        & $just -f $jf '--list' | ForEach-Object {
            if ($_ -match '^\s+(\S+)') {
                if ($names -contains $Matches[1]) {
                    if (-not $header) {
                        Write-Host 'Available recipes:'
                        $header = $true
                    }
                    Write-Host $_
                }
            }
        }
        if (-not $header) { Write-Note '  (no recipes found)' }
    }

    Write-Title 'Locale recipes (per mod + locale)'
    Write-Note ('=' * 40)
    Write-Host ''

    Write-Section 'Usage'
    Write-Cmd '  just mod-locale help'
    Write-Note '      this overview'
    Write-Cmd '  just mod-locale NAME LOCALE'
    Write-Note '      recipes for one locale (default)'
    Write-Cmd '  just mod-locale NAME LOCALE RECIPE'
    Write-Note '      run a recipe (seed-locale, apply, build-pak, ...)'
    Write-Host ''

    Write-Section 'Pipeline'
    Write-Note '  seed-locale / extract-csv   prepare build/.../locale.csv'
    Write-Note '  diff-locale                 archive vs active CSV'
    Write-Note '  apply → fromjson → strip → pack'
    Write-Note '  build-pak                   apply → fromjson → strip → pack'
    Write-Note '  extract-csv / apply / build-pak   auto-run just mod NAME tojson if json missing'
    Write-Host ''

    Write-Section 'Locale CSV'
    Write-Note '  mods/.../locale.csv    archive (reference only)'
    Write-Note '  build/.../locale.csv   active (used by apply)'
    Write-Host ''

    if ($name -and $locale) {
        $jf = Join-Path (Join-Path (Join-Path $mods $name) $locale) 'justfile'
        if (-not (Test-Path -LiteralPath $jf)) { throw "Locale not found: $name/$locale (expected $jf)" }
        Write-Section "$name / $locale"
        Write-Host ''
        Show-RecipeList $jf @('seed-locale', 'extract-csv', 'diff-locale', 'apply', 'fromjson', 'strip', 'pack', 'build-pak')
    } else {
        Write-Section 'Available mods'
        $exampleJf = $null
        Get-ChildItem -Path $mods -Directory | ForEach-Object {
            $modName = $_.Name
            $locales = @(Get-ChildItem -Path $_.FullName -Directory |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'justfile') } |
                ForEach-Object { $_.Name })
            if (-not $locales.Count) { return }
            if (-not $exampleJf) { $exampleJf = Join-Path (Join-Path $_.FullName $locales[0]) 'justfile' }
            Write-Host '  ' -NoNewline
            Write-Host $modName -ForegroundColor Cyan -NoNewline
            Write-Host '  [' -NoNewline -ForegroundColor DarkGray
            Write-Host ($locales -join ', ') -NoNewline -ForegroundColor White
            Write-Host ']' -ForegroundColor DarkGray
        }
        if (-not $exampleJf) {
            Write-Note '  (none yet — add under mods/<name>/<locale>/)'
        } else {
            Write-Host ''
            Write-Section 'Example recipe list'
            Show-RecipeList $exampleJf @('seed-locale', 'extract-csv', 'diff-locale', 'apply', 'fromjson', 'strip', 'pack', 'build-pak')
        }
    }

[doc("Mod recipes: just mod help | just mod NAME | just mod NAME RECIPE")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
mod NAME *ARGS:
    $ErrorActionPreference = 'Stop'
    $name = '{{NAME}}'
    $extra = '{{ARGS}}'.Trim()
    if ($name -eq 'help' -and -not $extra) {
        & '{{just_exe}}' '_help-mod'
        exit 0
    }
    if (-not $extra -or $extra -eq 'help') {
        & '{{just_exe}}' '_help-mod' '{{NAME}}'
        exit 0
    }
    $jf = Join-Path (Join-Path '{{mods_dir}}' '{{NAME}}') 'justfile'
    $argList = @('-f', $jf)
    $argList += $extra -split '\s+'
    & '{{just_exe}}' @argList

[doc("Locale recipes: just mod-locale help | just mod-locale NAME LOCALE | just mod-locale NAME LOCALE RECIPE")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
mod-locale NAME LOCALE='' *ARGS:
    $ErrorActionPreference = 'Stop'
    $name = '{{NAME}}'
    $locale = '{{LOCALE}}'.Trim()
    $extra = '{{ARGS}}'.Trim()
    if ($name -eq 'help' -and -not $locale -and -not $extra) {
        & '{{just_exe}}' '_help-mod-locale'
        exit 0
    }
    if (-not $locale) { throw 'Usage: just mod-locale NAME LOCALE [RECIPE]  (or: just mod-locale help)' }
    if (-not $extra -or $extra -eq 'help') {
        & '{{just_exe}}' '_help-mod-locale' '{{NAME}}' '{{LOCALE}}'
        exit 0
    }
    $jf = Join-Path (Join-Path (Join-Path '{{mods_dir}}' '{{NAME}}') '{{LOCALE}}') 'justfile'
    $argList = @('-f', $jf)
    $argList += $extra -split '\s+'
    & '{{just_exe}}' @argList
