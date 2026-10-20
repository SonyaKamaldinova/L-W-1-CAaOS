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
    echo "[PASSED] $1"
    ((PASSED++))
}

fail() {
    echo "[FAILED] $1"
    ((FAILED++))
}

cleanup() {
   rm -rf "$SCRIPT_DIR/test"
}

trap cleanup EXIT

if [[ ! -f "$SCRIPT" ]]; then
    echo "Error: not found $SCRIPT"
    exit 1
fi

if [[ ! -x "$SCRIPT" ]]; then
    echo "Make the main script executable."
    chmod +x "$SCRIPT"
fi

echo "=== Running tests for main.sh ==="


echo "--- Test 1: Incorrect number of arguments ---"
"$SCRIPT" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "The script correctly caught an argument error."
else
    fail "The script was not supposed to complete successfully."
fi


echo "--- Test 2: Non-existent directory ---"
"$SCRIPT" "does/not/exists" 80 2 >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "The script correctly caught an argument error."
else
    fail "The script was not supposed to finish successfully."
fi


echo "--- Test 3: Incorrect percentage ---"
"$SCRIPT" "$LOG_DIR" 150 2 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "The script correctly caught an argument error."
else
    fail "The script was not supposed to finish successfully."
fi


echo "--- Test 4: Incorrect number of files ---"
"$SCRIPT" "$LOG_DIR" 80 0 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 1 ]]; then
    pass "The script correctly caught an argument error."
else
    fail "The script was not supposed to finish successfully."
fi


echo "--- Test 5: Threshold NOT exceeded ---"
rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "test1" > "$LOG_DIR/file1.txt"
echo "test2" > "$LOG_DIR/file2.txt"
"$SCRIPT" "$LOG_DIR" 99 2 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 0 ]]; then
    pass "If the occupancy is below the threshold, the script completes successfully."
else
    fail "The script finished with an error."
fi


echo "--- Test 6: Threshold NOT exceeded ---"
rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "test1" > "$LOG_DIR/file1.txt"
echo "test2" > "$LOG_DIR/file2.txt"
"$SCRIPT" "$LOG_DIR" 99 2 "$BACKUP_DIR" >/dev/null 2>&1
ARCHIVES=$(find "$BACKUP_DIR" -type f -name '*.tar.gz' | wc -l)
if [[ "$ARCHIVES" -eq 0 ]]; then
    pass "If the occupancy level is below the threshold, no archive is created."
else
    fail "The archive should not have been created when the occupancy level was below the threshold."
fi


echo "--- Test 7: Threshold exceeded ---"
rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "old file 1" > "$LOG_DIR/old1.txt"
sleep 1
echo "old file 2" > "$LOG_DIR/old2.txt"
sleep 1
echo "new file" > "$LOG_DIR/new.txt"
truncate -s 50K "$LOG_DIR/filename.ext"
"$SCRIPT" "$LOG_DIR" 1 2 "$BACKUP_DIR" >/dev/null 2>&1
RC=$?
if [[ "$RC" -eq 0 ]]; then
    pass "Archiving is performed when the threshold is exceeded."
else
    fail "Archiving is not performed if the threshold is exceeded."
fi


echo "--- Test 8: Threshold exceeded ---"
rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "old file 1" > "$LOG_DIR/old1.txt"
sleep 1
echo "old file 2" > "$LOG_DIR/old2.txt"
sleep 1
echo "new file" > "$LOG_DIR/new.txt"
truncate -s 50K "$LOG_DIR/filename.ext"
"$SCRIPT" "$LOG_DIR" 1 2 "$BACKUP_DIR" >/dev/null 2>&1
ARCHIVE=$(find "$BACKUP_DIR" -type f -name '*.tar.gz' | head -n 1)
if [[ -n "$ARCHIVE" ]]; then
    pass "The .tar.gz archive has been created."
else
    fail "The .tar.gz archive was not created."
fi


echo "--- Test 8: Threshold exceeded ---"
rm -f "$LOG_DIR"/* "$BACKUP_DIR"/*
echo "old file 1" > "$LOG_DIR/old1.txt"
sleep 1
echo "old file 2" > "$LOG_DIR/old2.txt"
sleep 1
echo "new file" > "$LOG_DIR/new.txt"
truncate -s 50K "$LOG_DIR/filename.ext"
"$SCRIPT" "$LOG_DIR" 1 2 "$BACKUP_DIR" >/dev/null 2>&1
if [[ -n "$ARCHIVE" ]]; then
    if tar -tzf "$ARCHIVE" | grep -q "old1.txt" && tar -tzf "$ARCHIVE" | grep -q "old2.txt"; then
        pass "The oldest files ended up in the archive."
    else
        fail "The wrong files ended up in the archive."
    fi
fi

echo "=== Testing complete ==="
echo "PASSED: $PASSED"
echo "FAILED: $FAILED"
if [[ "$FAILED" -eq 0 ]]; then
    echo
    echo "All tests passed."
    exit 0
else
    echo
    echo "There are tests that haven't been passed."
    exit 1
fi
