\$MainScript = "./Backup-Logs.ps1"
if (-not (Test-Path \$MainScript)) {
    Write-Host "Ошибка: Скрипт \$MainScript не найден в текущей директории!" -ForegroundColor Red
    exit 1
}
function New-TestEnvironment {
    param([string]\$TestName)
    \(UniqueId = [Guid]::NewGuid().Guid.Substring(0, 8)\)TestRoot = Join-Path env:TEMP "PS_Lab1_\({TestName}_\){UniqueId}"
    LogDir = Join-Path TestRoot "log"
    BackupDir = Join-Path TestRoot "backup"
    New-Item -ItemType Directory -Path \$LogDir -Force | Out-Null
    New-Item -ItemType Directory -Path \$BackupDir -Force | Out-Null
    return [PSCustomObject]@{
        Root      = \$TestRoot
        LogDir    = \$LogDir
        BackupDir = \$BackupDir
    }
}
function Populate-LogDirectory {
    param(
        [string]\$Path,
        [int]\$Count
    )
    for (\$i = 1; i -le Count; \(i++) {\)filePath = Join-Path \(Path "log_file_\){i}.log"
        "Строка лога номер i" | Set-Content -Path filePath
        (Get-Item filePath).LastWriteTime = (Get-Date).AddMinutes(-(i * 5))
    }
}
Write-Host "=== Запуск независимых тест-кейсов ===" -ForegroundColor Cyan
Write-Host "[Тест 1] Проверка при N = 100%" -ForegroundColor Yellow
\$Env1 = New-TestEnvironment -TestName "Test1_NoExceed"
try {
    Populate-LogDirectory -Path \$Env1.LogDir -Count 4
    & \$MainScript -LogDir Env1.LogDir -N 100 -M 2 -BackupDir Env1.BackupDir
    remainingFiles = (Get-ChildItem -Path Env1.LogDir -File).Count
    archiveFiles = (Get-ChildItem -Path Env1.BackupDir -File).Count
    if (remainingFiles -eq 4 -and archiveFiles -eq 0) {
        Write-Host "-> РЕЗУЛЬТАТ: УСПЕШНО.`n" -ForegroundColor Green
    } else {
        Write-Host "-> РЕЗУЛЬТАТ: ПРОВАЛ.`n" -ForegroundColor Red
    }
}
finally {
    Remove-Item -Path \$Env1.Root -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[Тест 2] Проверка при N = 1%" -ForegroundColor Yellow
\$Env2 = New-TestEnvironment -TestName "Test2_WithExceed"
try {
    Populate-LogDirectory -Path \$Env2.LogDir -Count 5
    & \$MainScript -LogDir Env2.LogDir -N 1 -M 3 -BackupDir Env2.BackupDir
    remainingFiles = (Get-ChildItem -Path Env2.LogDir -File).Count
    archiveFiles = (Get-ChildItem -Path Env2.BackupDir -File).Count
    if (remainingFiles -eq 2 -and archiveFiles -eq 1) {
        Write-Host "-> РЕЗУЛЬТАТ: УСПЕШНО.`n" -ForegroundColor Green
    } else {
        Write-Host "-> РЕЗУЛЬТАТ: ПРОВАЛ.`n" -ForegroundColor Red
    }
}
finally {
    Remove-Item -Path \$Env2.Root -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[Тест 3] Проверка с пустой папкой" -ForegroundColor Yellow
\$Env3 = New-TestEnvironment -TestName "Test3_EmptyDir"
try {
    & \$MainScript -LogDir Env3.LogDir -N 1 -M 2 -BackupDir Env3.BackupDir
    archiveFiles = (Get-ChildItem -Path Env3.BackupDir -File).Count
    if (\$archiveFiles -eq 0) {
        Write-Host "-> РЕЗУЛЬТАТ: УСПЕШНО.`n" -ForegroundColor Green
    } else {
        Write-Host "-> РЕЗУЛЬТАТ: ПРОВАЛ.`n" -ForegroundColor Red
    }
}
finally {
    Remove-Item -Path \$Env3.Root -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "Все тесты завершены." -ForegroundColor Cyan
