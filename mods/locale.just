# Locale build layout and recipes.
# Import after mods/<name>/justfile; set locale, locale_dir in child.
# Optional on mod justfile: uexp_signatures (space-separated hex)

locale_build := mod_build + "/" + locale
locale_translated := locale_build + "/translated"
locale_translated_uasset := locale_build + "/translated_uasset"
locale_stripped := locale_build + "/stripped_uasset"
locale_csv_mod := locale_dir + "/locale.csv"
locale_csv_build := locale_build + "/locale.csv"
locale_assets := locale_dir + "/assets"
dist_pak := dist_dir + "/mod_" + mod + "_" + locale + "_P.pak"

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
extract-csv: _require-json _extract-csv

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
apply: _require-json _apply

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_fromjson:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    Write-Host "[${tag}:fromjson] starting..."
    Push-Location '{{root}}'
    try {
        $args = @(
            'run', 'python', 'scripts/convert.py', 'fromjson',
            '{{locale_translated}}', '{{locale_translated_uasset}}',
            '--uassetgui', '{{uassetgui}}',
            '--version', '{{ue_version}}',
            '--usmap', '{{usmap}}',
            '-w', '{{workers}}'
        )
        foreach ($sig in '{{uexp_signatures}}'.Trim() -split '\s+') {
            if ($sig) { $args += @('--uexp-signature', $sig) }
        }
        & '{{uv}}' @args
        if ($LASTEXITCODE -ne 0) { throw "convert.py fromjson failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

[doc("Convert translated json back to uasset/uexp in build/.../translated_uasset/")]
fromjson: apply extract-usmap fetch-uassetgui _fromjson

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
strip: fromjson _strip

[script("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass")]
_pack:
    $ErrorActionPreference = 'Stop'
    $tag = '{{mod}}:{{locale}}'
    Write-Host "[${tag}:pack] starting..."
    New-Item -ItemType Directory -Force -Path '{{dist_dir}}' | Out-Null
    & '{{repak}}' pack '{{locale_stripped}}' '{{dist_pak}}'
    if ($LASTEXITCODE -ne 0) { throw "repak pack failed with exit code $LASTEXITCODE" }
    Write-Host "[${tag}:pack] wrote {{dist_pak}}"

[doc("repak pack to dist/mod_MOD_LOCALE_P.pak")]
pack: strip fetch-repak _pack

[doc("Full locale pipeline: apply, fromjson, strip, pack")]
all: pack
