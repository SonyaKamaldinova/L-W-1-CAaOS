#!/bin/bash

SCRIPT="./main.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/test"
LOG_DIR="$SCRIPT_DIR/test/log"
BACKUP_DIR="$SCRIPT_DIR/test/backup"
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

PASSED=0
FAILED=0

pass() {
    echo "[ПРОЙДЕН] $1"
    ((PASSED++))
}

fail() {
    echo "[ОШИБКА] $1"
    ((FAILED++))
}

cleanup() {
   rm -rf "$SCRIPT_DIR/test"
}

trap cleanup EXIT

if [[ ! -f "$SCRIPT" ]]; then
    echo "Ошибка: не найден $SCRIPT"
    exit 1
fi

if [[ ! -x "$SCRIPT" ]]; then
    echo "Делаем основной скрипт исполняемым..."
    chmod +x "$SCRIPT"
fi

echo "=== Запуск тестов для main.sh ==="


echo "--- Тест 1: Неверное количество аргументов ---"
"$SCRIPT" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "Скрипт корректно поймал ошибку аргументов."
else
    fail "Скрипт не должен был завершиться успешно."
fi


echo "--- Тест 2: Несуществующий каталог ---"
"$SCRIPT" "does/not/exists" 80 2 >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "Скрипт корректно поймал ошибку аргументов."
else
    fail "Скрипт не должен был завершиться успешно."
fi


echo "--- Тест 3: Неверный процент ---"
"$SCRIPT" "$LOG_DIR" 150 2 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "Скрипт корректно поймал ошибку аргументов."
else
    fail "Скрипт не должен был завершиться успешно."
fi


echo "--- Тест 4: Неверный процент ---"
"$SCRIPT" "$LOG_DIR" 80 0 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "Скрипт корректно поймал ошибку аргументов."
else
    fail "Скрипт не должен был завершиться успешно."
fi


echo "--- Тест 5, 6: Порог НЕ превышен ---"
rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "test1" > "$LOG_DIR/file1.txt"
echo "test2" > "$LOG_DIR/file2.txt"
TEST_USAGE_PERCENT=50 "$SCRIPT" "$LOG_DIR" 80 2 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 0 ]]; then
    pass "При заполненности ниже порога скрипт завершается успешно."
else
    fail "Скрипт завершился с ошибкой."
fi

ARCHIVES=$(find "$BACKUP_DIR" -type f -name '*.tar.gz' | wc -l)
if [[ "$ARCHIVES" -eq 0 ]]; then
    pass "При заполненности ниже порога архив не создаётся."
else
    fail "При заполненности ниже порога архив не должен был создаваться."
fi


echo "--- Тест 7, 8, 9, 10: Порог превышен ---"
rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "old file 1" > "$LOG_DIR/old1.txt"
sleep 1
echo "old file 2" > "$LOG_DIR/old2.txt"
sleep 1
echo "new file" > "$LOG_DIR/new.txt"
TEST_USAGE_PERCENT=90 "$SCRIPT" "$LOG_DIR" 10 2 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 0 ]]; then
    pass "При превышении порога архивация выполняется."
else
    fail "При превышении порога архивация не выполняется."
fi

ARCHIVE=$(find "$BACKUP_DIR" -type f -name '*.tar.gz' | head -n 1)
if [[ -n "$ARCHIVE" ]]; then
    pass "Архив .tar.gz создан."
else
    fail "Архив .tar.gz не создан."
fi

if [[ -n "$ARCHIVE" ]]; then
    if tar -tzf "$ARCHIVE" | grep -q "old1.txt" && tar -tzf "$ARCHIVE" | grep -q "old2.txt"; then
        pass "В архив попали самые старые файлы."
    else
        fail "В архив попали не те файлы."
    fi
fi

rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "old log" > "$LOG_DIR/old.txt"
echo "already archived" > "$LOG_DIR/already.tar.gz"
TEST_USAGE_PERCENT=90 "$SCRIPT" "$LOG_DIR" 80 2 "$BACKUP_DIR" >/dev/null 2>&1
ARCHIVE=$(find "$BACKUP_DIR" -type f -name '*.tar.gz' | head -n 1)
if [[ -n "$ARCHIVE" ]]; then
    if tar -tzf "$ARCHIVE" | grep -q "already.tar.gz"; then
        fail "Фильтрация ошибочно включила существующий .tar.gz"
    else
        pass "Фильтрация исключает существующие .tar.gz"
    fi
fi
echo "=== Тестирование завершено ==="
echo "Успешно: $PASSED"
echo "Ошибок:  $FAILED"
if [[ "$FAILED" -eq 0 ]]; then
    echo
    echo "Все тесты пройдены."
    exit 0
else
    echo
    echo "Есть непройденные тесты."
    exit 1
fi
