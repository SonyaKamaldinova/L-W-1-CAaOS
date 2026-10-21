# Usage: .\main.ps1 <directory_with_logs> <percent> <number_of_old_files> <directory_with_archive>

param(
    [string]$Folder,
    [string]$Threshold,
    [string]$MFiles,
    [string]$Backup,
    [Parameter(ValueFromRemainingArguments = $true)]
    $Extra
)

# --- Check arguments ---
if (-not $Folder -or -not $Threshold -or -not $MFiles -or -not $Backup -or $Extra) {
    Write-Output "Using: .\main.ps1 <directory_with_logs> <percent> <number_of_old_files> <directory_with_archive>"
    exit 1
}

if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    Write-Output "Error: The specified folder does not exist."
    exit 1
}

if ($Threshold -notmatch '^[0-9]+$' -or [int]$Threshold -lt 1 -or [int]$Threshold -gt 100) {
    Write-Output "Error: the threshold must be an integer from 1 to 100."
    exit 1
}

if ($MFiles -notmatch '^[1-9][0-9]*$') {
    Write-Output "Error: the number of files must be a positive number."
    exit 1
}

$Threshold = [int]$Threshold
$MFiles = [int]$MFiles

# --- Calculate folder size ---
$sum = (Get-ChildItem -LiteralPath $Folder -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum
if ($null -eq $sum) { $sum = 0 }
$currentSize = [int64]$sum
Write-Output "Current folder size: $currentSize byte"

$folderLimit = 1048576   # 1048576 byte = 1 MB

$usagePercent = [int64][math]::Floor($currentSize * 100 / $folderLimit)
Write-Output "Current occupancy as a percentage: $usagePercent%"
Write-Output "Threshold: $Threshold%"

if ($usagePercent -le $Threshold) {
    Write-Output "The threshold has not been exceeded. Archiving is not required."
    exit 0
}

Write-Output "Attention: Limit exceeded! Archiving of old files is beginning."

# --- Find files (only in the top folder), oldest first ---
$files = @(Get-ChildItem -LiteralPath $Folder -File -Force | Sort-Object LastWriteTime)

if ($files.Count -eq 0) {
    Write-Output "No files found for archiving."
    exit 0
}

if ($MFiles -gt $files.Count) {
    $MFiles = $files.Count
}

Write-Output "List of files suitable for moving to the archive:"
$files | ForEach-Object { Write-Output $_.FullName }

# --- Create archive folder ---
try {
    New-Item -ItemType Directory -Path $Backup -Force -ErrorAction Stop | Out-Null
}
catch {
    Write-Output "Error: unable to create directory '$Backup'."
    exit 1
}

$archiveName = Join-Path $Backup ("backup_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".zip")

$selected = @($files | Select-Object -First $MFiles)

Write-Output "The following files will be archived:"
$selected | ForEach-Object { Write-Output "  $($_.Name)" }

# --- Create archive ---
try {
    Compress-Archive -LiteralPath $selected.FullName -DestinationPath $archiveName -ErrorAction Stop
    Write-Output "Success! Archive saved in: $archiveName"
}
catch {
    Write-Output "Error creating archive."
    exit 1
}

exit 0
