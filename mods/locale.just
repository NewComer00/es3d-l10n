# Locale build layout and recipes.
# Import after mods/<name>/justfile; set locale, locale_dir in child.
# Optional on mod justfile: uexp_signatures (list of hex uexp headers)

locale_build := mod_build + "/" + locale
locale_translated := locale_build + "/translated"
locale_translated_uasset := locale_build + "/translated_uasset"
locale_stripped := locale_build + "/stripped_uasset"
locale_csv_mod := locale_dir + "/locale.csv"
locale_csv_build := locale_build + "/locale.csv"
locale_assets := locale_dir + "/assets"
dist_locale_dir := dist_dir + "/" + locale
dist_paks_dir := dist_locale_dir + "/Everlasting_summer/Content/Paks"
dist_pak := dist_paks_dir + "/mod_" + mod + "_" + locale + "_P.pak"

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_extract-csv:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    $out = '{{locale_csv_build}}'
    Write-Host "[${tag}:extract-csv] writing $out"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
    Push-Location '{{root}}'
    try {
        & '{{uv}}' run python scripts/extract_to_csv.py '{{mod_json}}' --output $out --natural-sort --skip-existing
        if ($LASTEXITCODE -ne 0) { throw "extract_to_csv failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

[doc("Extract strings from json to build/MOD/LOCALE/locale.csv")]
extract-csv: _ensure-json _extract-csv

[doc("Copy frozen mods/.../locale.csv archive to build/.../locale.csv")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
seed-locale:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    $archive = '{{locale_csv_mod}}'
    $out = '{{locale_csv_build}}'
    if (-not (Test-Path -LiteralPath $archive)) {
        throw "Archive not found: $archive"
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
    Copy-Item -LiteralPath $archive -Destination $out -Force
    Write-Host "[${tag}:seed-locale] copied archive -> $out"
    Write-Host "[${tag}:seed-locale] edit build CSV for active work; mods locale.csv stays frozen"

[doc("Diff archive mods/.../locale.csv vs active build/.../locale.csv (opens in cursor/code/codium)")]
[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
diff-locale:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    $archive = '{{locale_csv_mod}}'
    $active = '{{locale_csv_build}}'
    Write-Host "[${tag}:diff-locale] archive vs active"
    Push-Location '{{root}}'
    try {
        & '{{uv}}' run python scripts/diff_locale_csv.py $archive $active --open
        if ($LASTEXITCODE -ne 0) { throw "diff_locale_csv failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_apply:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    Write-Host "[${tag}:apply] starting..."
    $archive = '{{locale_csv_mod}}'
    $csv = '{{locale_csv_build}}'
    if (-not (Test-Path -LiteralPath $csv)) {
        $hint = "Run: just -f mods/{{mod}}/{{locale}}/justfile seed-locale  (copy archive) or extract-csv  (from json)"
        if (Test-Path -LiteralPath $archive) {
            throw "Build locale CSV missing: $csv`nArchive exists at $archive (frozen, not used by apply).`n$hint"
        }
        throw "Build locale CSV missing: $csv`n$hint"
    }
    Write-Host "[${tag}:apply] using build locale CSV: $csv"
    if (Test-Path -LiteralPath $archive) {
        Write-Host "[${tag}:apply] archive (unused): $archive"
    }
    Push-Location '{{root}}'
    try {
        & '{{uv}}' run python scripts/apply_translations.py '{{mod_json}}' $csv --output '{{locale_translated}}'
        if ($LASTEXITCODE -ne 0) { throw "apply_translations failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

[doc("Apply build CSV translations to json in build/.../translated/")]
apply: _ensure-json _apply

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_merge-extracted:
    $ErrorActionPreference = 'Stop'
    if ('{{merge_extracted}}' -ne 'true') { return }
    $tag = '{{mod}}:{{locale}}'
    $extracted = '{{mod_extracted}}'
    $translated = '{{locale_translated}}'
    $out = '{{locale_translated_uasset}}'
    if (-not (Test-Path -LiteralPath $extracted)) {
        throw "Extracted dir missing: $extracted. Run: just mod {{mod}} unpack"
    }
    Write-Host "[${tag}:merge-extracted] copy extracted -> $out"
    if (Test-Path -LiteralPath $out) {
        Remove-Item -LiteralPath $out -Recurse -Force
    }
    Copy-Item -LiteralPath $extracted -Destination $out -Recurse -Force
    if (Test-Path -LiteralPath $translated) {
        Write-Host "[${tag}:merge-extracted] overlay translated json"
        Copy-Item -Path (Join-Path $translated '*') -Destination $out -Recurse -Force
    } else {
        throw "Translated dir missing: $translated. Run apply first."
    }

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_fromjson:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    Write-Host "[${tag}:fromjson] starting..."
    $inputDir = if ('{{fromjson_inplace}}' -eq 'true') { '{{locale_translated_uasset}}' } else { '{{locale_translated}}' }
    $workers = '{{fromjson_workers}}'.Trim()
    if (-not $workers) { $workers = '{{workers}}' }
    $maxRetries = '{{fromjson_max_retries}}'.Trim()
    Push-Location '{{root}}'
    try {
        $args = @(
            'run', 'python', 'scripts/convert.py', 'fromjson',
            $inputDir, '{{locale_translated_uasset}}',
            '--uassetgui', '{{uassetgui}}',
            '--version', '{{ue_version}}',
            '--usmap', '{{usmap}}',
            '-w', $workers
        )
        if ($maxRetries) { $args += @('--max-retries', $maxRetries) }
        $signatures = @('{{ join_list(uexp_signatures) }}'.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
        foreach ($sig in $signatures) {
            if ($sig) { $args += @('--uexp-signature', $sig) }
        }
        & '{{uv}}' @args
        if ($LASTEXITCODE -ne 0) { throw "convert.py fromjson failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

[doc("Convert translated json back to uasset/uexp in build/.../translated_uasset/")]
fromjson: apply extract-usmap fetch-uassetgui _merge-extracted _fromjson

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_ensure-assets:
    # Override in mods/.../LOCALE/justfile to fetch files into mods/.../assets/ before strip.

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_strip:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    $stripped = '{{locale_stripped}}'
    Write-Host "[${tag}:strip] starting..."
    if (Test-Path -LiteralPath $stripped -PathType Leaf) {
        Remove-Item -LiteralPath $stripped -Force
    }
    Push-Location '{{root}}'
    try {
        & '{{uv}}' run python scripts/strip_assets.py '{{locale_translated_uasset}}' $stripped
        if ($LASTEXITCODE -ne 0) { throw "strip_assets failed with exit code $LASTEXITCODE" }
        $assets = '{{locale_assets}}'
        if (Test-Path -LiteralPath $assets) {
            Write-Host "[${tag}:strip] overlaying assets from $assets"
            New-Item -ItemType Directory -Force -Path $stripped | Out-Null
            Copy-Item -Path (Join-Path $assets '*') -Destination $stripped -Recurse -Force
        }
    } finally {
        Pop-Location
    }

[doc("Copy sidecar assets; overlay mods/.../assets/ into build/.../stripped_uasset/")]
strip: fromjson _ensure-assets _strip

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_pack:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    Write-Host "[${tag}:pack] starting..."
    New-Item -ItemType Directory -Force -Path '{{dist_paks_dir}}' | Out-Null
    & '{{repak}}' pack '{{locale_stripped}}' '{{dist_pak}}'
    if ($LASTEXITCODE -ne 0) { throw "repak pack failed with exit code $LASTEXITCODE" }
    Write-Host "[${tag}:pack] wrote {{dist_pak}}"

[doc("repak pack to dist/LOCALE/.../Content/Paks/mod_MOD_LOCALE_P.pak")]
pack: strip fetch-repak _pack

[doc("Apply translations and pack into dist/<locale>/ (game-tree layout)")]
build-pak: pack
