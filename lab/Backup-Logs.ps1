[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LogDir,
    [ValidateRange(1, 100)]
    [int]$N = 80,
    [ValidateRange(1, [int]::MaxValue)]
    [int]$M = 5,
    [string]$BackupDir = $(if ($env:BACKUP_DIR) { $env:BACKUP_DIR } else { "Backup" })
)
function Get-DirectoryUsagePercent {
    param([string]$Path)
    $volumeInfo = Get-Volume -FilePath $Path
    if (-not $volumeInfo -or $volumeInfo.Size -le 0) {
        throw "Не удалось получить информацию о томе для '$Path'"
    }
    $occupied = $volumeInfo.Size - $volumeInfo.SizeRemaining
    return [int][math]::Ceiling(($occupied / $volumeInfo.Size) * 100)
}
function Select-OldestFiles {
    param(
        [string]$Path,
        [int]$Count
    )
    return @(
        Get-ChildItem -LiteralPath $Path -File -ErrorAction Stop |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -Last $Count
    )
}
function New-BackupArchive {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string[]]$FileNames
    )
    $targetResolved = $null
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    }
    $targetResolved = (Resolve-Path -LiteralPath $TargetPath).Path
    $timeMarker = Get-Date -Format "yyyyMMdd_HHmmss"
    $archivePath = Join-Path $targetResolved "backup_$timeMarker.tar.gz"
    & tar -czf $archivePath -C $SourcePath @FileNames
    if ($LASTEXITCODE -ne 0) {
        throw "Утилита tar завершилась с кодом $LASTEXITCODE"
    }
    return $archivePath
}
function Remove-ArchivedFiles {
    param([System.IO.FileInfo[]]$Items)
    foreach ($item in $Items) {
        if ($item.Exists) {
            Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
        }
    }
}
# --- Основная логика ---
if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) {
    Write-Host "Ошибка: '$LogDir' не является каталогом" -ForegroundColor Red
    exit 1
}
$resolvedLogDir = (Resolve-Path -LiteralPath $LogDir).Path
Write-Host "Каталог для обработки: $resolvedLogDir"
try {
    $usagePercent = Get-DirectoryUsagePercent -Path $resolvedLogDir
}
catch {
    Write-Host "Ошибка при определении занятости: $_" -ForegroundColor Red
    exit 1
}
Write-Host "Текущая занятость: $usagePercent%"

if ($usagePercent -le $N) {
    Write-Host "Занятость $usagePercent% не превышает порог $N% — действий не требуется"
    exit 0
}
Write-Host "Занятость $usagePercent% превышает порог $N%, выполняется архивация $M наиболее старых файлов"
$oldestFiles = Select-OldestFiles -Path $resolvedLogDir -Count $M
if ($oldestFiles.Count -eq 0) {
    Write-Host "Подходящих файлов для архивации не найдено"
    exit 0
}
Write-Host "Отобраны файлы:"
$oldestFiles | ForEach-Object { Write-Host "  $($_.Name)" }
try {
    $createdArchive = New-BackupArchive -SourcePath $resolvedLogDir `
                                        -TargetPath $BackupDir `
                                        -FileNames ($oldestFiles | ForEach-Object { $_.Name })
    Write-Host "Архив успешно создан: $createdArchive"
    Remove-ArchivedFiles -Items $oldestFiles
    Write-Host "Исходные файлы удалены из $resolvedLogDir"
}
catch {
    Write-Host "Ошибка: архивация не выполнена — $_" -ForegroundColor Red
    exit 1
}
