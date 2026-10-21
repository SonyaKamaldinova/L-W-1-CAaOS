# Test script for main.ps1
# Usage: .\test_main.ps1
# main.ps1 must be in the same folder as this script.

$script = Join-Path $PSScriptRoot "main.ps1"
$passed = 0
$failed = 0

function Check($name, $condition) {
    if ($condition) {
        Write-Host "[PASS] $name" -ForegroundColor Green
        $script:passed++
    }
    else {
        Write-Host "[FAIL] $name" -ForegroundColor Red
        $script:failed++
    }
}

# Run main.ps1 and return its output text and exit code
function Run-Main {
    $out = & $script @args 2>&1 | Out-String
    return @{ Out = $out; Code = $LASTEXITCODE }
}

# Create a test folder with 5 files, 100 KB each.
# f1 is the oldest, f5 is the newest.  Total = 500000 byte = 47%
function New-TestFolder($path) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    for ($i = 1; $i -le 5; $i++) {
        $file = Join-Path $path "f$i.log"
        [System.IO.File]::WriteAllBytes($file, (New-Object byte[] 100000))
        (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-(10 - $i))
    }
}

# Get names of files inside a zip archive
function Get-ZipNames($zip) {
    $tmp = Join-Path $root ("unzip_" + [guid]::NewGuid().ToString("N"))
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp
    $names = @(Get-ChildItem $tmp -File | Sort-Object Name | ForEach-Object { $_.Name })
    return $names
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("archiver_test_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root | Out-Null
Write-Host "Test folder: $root"
Write-Host ""

# ---------- Argument checks ----------
Write-Host "--- Argument checks ---"

$logs = Join-Path $root "logs1"
$arch = Join-Path $root "arch1"
New-TestFolder $logs

$r = Run-Main
Check "No arguments -> exit 1" ($r.Code -eq 1)

$r = Run-Main $logs 10 2
Check "3 arguments -> exit 1" ($r.Code -eq 1)

$r = Run-Main $logs 10 2 $arch "extra"
Check "5 arguments -> exit 1" ($r.Code -eq 1)

$r = Run-Main (Join-Path $root "no_such_folder") 10 2 $arch
Check "Folder does not exist -> exit 1" ($r.Code -eq 1)

foreach ($bad in @("abc", "0", "101", "-5", "5.5")) {
    $r = Run-Main $logs $bad 2 $arch
    Check "Bad threshold '$bad' -> exit 1" ($r.Code -eq 1)
}

foreach ($bad in @("abc", "0", "-3", "1.5")) {
    $r = Run-Main $logs 10 $bad $arch
    Check "Bad number of files '$bad' -> exit 1" ($r.Code -eq 1)
}

Check "Archive folder not created on bad arguments" (-not (Test-Path $arch))

# ---------- Threshold not exceeded ----------
Write-Host ""
Write-Host "--- Threshold not exceeded ---"

$r = Run-Main $logs 90 2 $arch
Check "Usage 47% and threshold 90% -> exit 0" ($r.Code -eq 0)
Check "Message says archiving is not required" ($r.Out -match "not required")
Check "No archive folder created" (-not (Test-Path $arch))

$r = Run-Main $logs 47 2 $arch
Check "Usage equal to threshold (47%) -> no archiving" (($r.Code -eq 0) -and -not (Test-Path $arch))

# ---------- Threshold exceeded ----------
Write-Host ""
Write-Host "--- Threshold exceeded ---"

$r = Run-Main $logs 10 2 $arch
Check "Usage 47% and threshold 10% -> exit 0" ($r.Code -eq 0)
Check "Message says limit exceeded" ($r.Out -match "Limit exceeded")
$zips = @(Get-ChildItem $arch -Filter "backup_*.zip" -ErrorAction SilentlyContinue)
Check "Exactly one archive created" ($zips.Count -eq 1)
if ($zips.Count -eq 1) {
    $names = Get-ZipNames $zips[0].FullName
    Check "Archive has 2 files" ($names.Count -eq 2)
    Check "Archive has the 2 oldest files (f1, f2)" (($names -join ",") -eq "f1.log,f2.log")
}
Check "Original files are still in the folder" (@(Get-ChildItem $logs -File).Count -eq 5)

# ---------- More files requested than exist ----------
Write-Host ""
Write-Host "--- More files requested than exist ---"

$logs2 = Join-Path $root "logs2"
$arch2 = Join-Path $root "arch2"
New-TestFolder $logs2

$r = Run-Main $logs2 10 100 $arch2
Check "M=100 with 5 files -> exit 0" ($r.Code -eq 0)
$zips = @(Get-ChildItem $arch2 -Filter "backup_*.zip" -ErrorAction SilentlyContinue)
if ($zips.Count -eq 1) {
    $names = Get-ZipNames $zips[0].FullName
    Check "All 5 files archived" ($names.Count -eq 5)
}
else {
    Check "Archive created" $false
}

# ---------- Nested archive folder ----------
Write-Host ""
Write-Host "--- Nested archive folder ---"

$logs3 = Join-Path $root "logs3"
$arch3 = Join-Path $root "a\b\c"
New-TestFolder $logs3

$r = Run-Main $logs3 10 1 $arch3
Check "Nested archive folder is created" (($r.Code -eq 0) -and (Test-Path $arch3))
$zips = @(Get-ChildItem $arch3 -Filter "backup_*.zip" -ErrorAction SilentlyContinue)
if ($zips.Count -eq 1) {
    $names = Get-ZipNames $zips[0].FullName
    Check "M=1 -> only the oldest file (f1)" (($names -join ",") -eq "f1.log")
}
else {
    Check "Archive created in nested folder" $false
}

# ---------- Files only in a subfolder ----------
Write-Host ""
Write-Host "--- Big file only in a subfolder ---"

$logs4 = Join-Path $root "logs4"
$sub = Join-Path $logs4 "sub"
New-Item -ItemType Directory -Path $sub -Force | Out-Null
[System.IO.File]::WriteAllBytes((Join-Path $sub "big.log"), (New-Object byte[] 500000))

$r = Run-Main $logs4 10 2 (Join-Path $root "arch4")
Check "No files in top folder -> exit 0" ($r.Code -eq 0)
Check "Message says no files found" ($r.Out -match "No files found")

# ---------- Empty folder ----------
Write-Host ""
Write-Host "--- Empty folder ---"

$logs5 = Join-Path $root "logs5"
New-Item -ItemType Directory -Path $logs5 | Out-Null
$r = Run-Main $logs5 10 2 (Join-Path $root "arch5")
Check "Empty folder -> exit 0, nothing to do" (($r.Code -eq 0) -and ($r.Out -match "not required"))

# ---------- File names with spaces and brackets ----------
Write-Host ""
Write-Host "--- Tricky file names ---"

$logs6 = Join-Path $root "logs6"
$arch6 = Join-Path $root "arch6"
New-Item -ItemType Directory -Path $logs6 | Out-Null
$oldFile = Join-Path $logs6 "my log [1].txt"
$newFile = Join-Path $logs6 "new.txt"
[System.IO.File]::WriteAllBytes($oldFile, (New-Object byte[] 300000))
[System.IO.File]::WriteAllBytes($newFile, (New-Object byte[] 300000))
(Get-Item -LiteralPath $oldFile).LastWriteTime = (Get-Date).AddDays(-3)

$r = Run-Main $logs6 10 1 $arch6
$zips = @(Get-ChildItem $arch6 -Filter "backup_*.zip" -ErrorAction SilentlyContinue)
if ($zips.Count -eq 1) {
    $names = Get-ZipNames $zips[0].FullName
    Check "File with spaces and [brackets] archived" (($names -join ",") -eq "my log [1].txt")
}
else {
    Check "Archive created for tricky file name" $false
}

# ---------- Cleanup and result ----------
Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Passed: $passed   Failed: $failed"
if ($failed -gt 0) { exit 1 }
exit 0
