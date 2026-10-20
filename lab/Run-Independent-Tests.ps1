# Run-Independent-Tests.ps1
# Независимое тестирование для Backup-Logs.ps1

\$MainScript = "./Backup-Logs.ps1"

# Проверяем, существует ли основной скрипт
if (-not (Test-Path \$MainScript)) {
    Write-Host "Ошибка: Скрипт \$MainScript не найден в текущей директории!" -ForegroundColor Red
    exit 1
}

# Функция-помощник для создания уникальной тестовой среды
function New-TestEnvironment {
    param([string]\$TestName)
    
    # Создаем уникальный путь для конкретного теста
    \$UniqueId = [Guid]::NewGuid().Guid.Substring(0, 8)
    \(TestRoot = Join-Path\)env:TEMP "PS_Lab1_\({TestName}_\){UniqueId}"
    \(LogDir   = Join-Path\)TestRoot "log"
    \(BackupDir = Join-Path\)TestRoot "backup"
    
    New-Item -ItemType Directory -Path \$LogDir -Force | Out-Null
    New-Item -ItemType Directory -Path \$BackupDir -Force | Out-Null
    
    # Возвращаем объект со путями
    return [PSCustomObject]@{
        Root      = \$TestRoot
        LogDir    = \$LogDir
        BackupDir = \$BackupDir
    }
}

# Функция для наполнения лог-папки файлами разного "возраста"
function Populate-LogDirectory {
    param(
        [string]\$Path,
        [int]\$Count
    )
    for (\$i = 1; \(i -le\)Count; \(i++) {\)filePath = Join-Path \(Path "log_file_\)i.log"
        "Строка лога номер \(i" \vert{} Set-Content -Path \)filePath
        # Искусственно старим файлы: каждый следующий файл старше предыдущего на 5 минут
        (Get-Item \(filePath).LastWriteTime = (Get-Date).AddMinutes(-(\)i * 5))
    }
}


Write-Host "=== Запуск независимых тест-кейсов ===" -ForegroundColor Cyan


# ----------------------------------------------------------------------
# ТЕСТ-КЕЙС 1: Проверка работы, когда порог диска НЕ превышен (N=100%)
# ----------------------------------------------------------------------
Write-Host "[Тест 1] Проверка при N = 100% (Архивация не должна сработать)" -ForegroundColor Yellow
\$Env1 = New-TestEnvironment -TestName "Test1_NoExceed"

try {
    # Создаем 4 файла
    Populate-LogDirectory -Path \$Env1.LogDir -Count 4
    
    # Запускаем основной скрипт с заведомо недостижимым порогом
    & \$MainScript -LogDir \(Env1.LogDir -N 100 -M 2 -BackupDir\)Env1.BackupDir
    
    \(remainingFiles = (Get-ChildItem -Path\)Env1.LogDir -File).Count
    \(archiveFiles   = (Get-ChildItem -Path\)Env1.BackupDir -File).Count
    
    if (\(remainingFiles -eq 4 -and\)archiveFiles -eq 0) {
        Write-Host "-> РЕЗУЛЬТАТ: УСПЕШНО. Файлы не тронуты, архив не создавался.`n" -ForegroundColor Green
    } else {
        Write-Host "-> РЕЗУЛЬТАТ: ПРОВАЛ. Ожидалось логов: 4, архивов: 0. Получено: логов: $remainingFiles, архивов: $archiveFiles`n" -ForegroundColor Red
    }
}
finally {
    # Удаляем окружение первого теста независимо от результата
    Remove-Item -Path \$Env1.Root -Recurse -Force -ErrorAction SilentlyContinue
}


# ----------------------------------------------------------------------
# ТЕСТ-КЕЙС 2: Проверка архивации при превышении порога (N=1%)
# ----------------------------------------------------------------------
Write-Host "[Тест 2] Проверка при N = 1% (Должно заархивировать M самых старых)" -ForegroundColor Yellow
\$Env2 = New-TestEnvironment -TestName "Test2_WithExceed"

try {
    # Создаем 5 файлов. Файлы создаются так, что log_file_5.log — самый старый, а log_file_1.log — самый свежий.
    Populate-LogDirectory -Path \$Env2.LogDir -Count 5
    
    # Задаем жесткий порог 1% и требуем упаковать M=3 самых старых файлов
    & \$MainScript -LogDir \(Env2.LogDir -N 1 -M 3 -BackupDir\)Env2.BackupDir
    
    \(remainingFiles = (Get-ChildItem -Path\)Env2.LogDir -File).Count
    \(archiveFiles   = (Get-ChildItem -Path\)Env2.BackupDir -File).Count
    
    # Должно остаться: 5 - 3 = 2 файла. Должен появиться 1 архив.
    if (\(remainingFiles -eq 2 -and\)archiveFiles -eq 1) {
        Write-Host "-> РЕЗУЛЬТАТ: УСПЕШНО. 3 старых файла упакованы и удалены.`n" -ForegroundColor Green
    } else {
        Write-Host "-> РЕЗУЛЬТАТ: ПРОВАЛ. Ожидалось логов: 2, архивов: 1. Получено: логов: $remainingFiles, архивов: $archiveFiles`n" -ForegroundColor Red
    }
}
finally {
    Remove-Item -Path \$Env2.Root -Recurse -Force -ErrorAction SilentlyContinue
}


# ----------------------------------------------------------------------
# ТЕСТ-КЕЙС 3: Проверка поведения при пустой папке логов
# ----------------------------------------------------------------------
Write-Host "[Тест 3] Проверка поведения с пустой папкой логов" -ForegroundColor Yellow
\$Env3 = New-TestEnvironment -TestName "Test3_EmptyDir"

try {
    # Запускаем скрипт на пустой папке с порогом 1%
    & \$MainScript -LogDir \(Env3.LogDir -N 1 -M 2 -BackupDir\)Env3.BackupDir
    
    \(archiveFiles = (Get-ChildItem -Path\)Env3.BackupDir -File).Count
    
    if (\$archiveFiles -eq 0) {
        Write-Host "-> РЕЗУЛЬТАТ: УСПЕШНО. Скрипт корректно завершился без ошибок, архив не создан.`n" -ForegroundColor Green
    } else {
        Write-Host "-> РЕЗУЛЬТАТ: ПРОВАЛ. В пустой папке откуда-то создался архив.`n" -ForegroundColor Red
    }
}
finally {
    Remove-Item -Path \$Env3.Root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Все тесты завершены." -ForegroundColor Cyan
