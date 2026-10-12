#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Использование: $0 <путь_к_папке_с_логами> <процент_заполнения> <кол_во_стары_файлов> <путь_к_папке_с_архивом>"
    exit 1
fi

FOLDER="$1"
THRESHOLD="$2"
M_FILES="$3"
BACKUP="$4"

if [ ! -d "$FOLDER" ]; then
    echo "Ошибка: Указанная папка не существует."
    exit 1
fi

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || \
   (( THRESHOLD < 1 || THRESHOLD > 100 )); then
    echo "Ошибка: порог должен быть целым числом от 1 до 100."
    exit 1
fi

if ! [[ "$M_FILES" =~ ^[1-9][0-9]*$ ]]; then
    echo "Ошибка: количество файлов должно быть положительным числом."
    exit 1
fi

USAGE_PERCENT=$(df -P "$FOLDER" | awk 'NR==2 {gsub("%", "", $5); print $5}')
echo "Текущая заполненность в процентах: ${USAGE_PERCENT}%"
echo "Порог: ${THRESHOLD}%"

if (( USAGE_PERCENT <= THRESHOLD )); then
    echo "Порог не превышен. Архивация не требуется."
    exit 0
fi

echo "Внимание: Превышен лимит! Начинается архивация старых файлов."

mapfile -t FILES < <(find "$FOLDER" -maxdepth 1 -type f ! -name '*.tar.gz' -printf '%T@ %p\n' |sort -n | cut -d' ' -f2-)
    
if [ ${#FILES[@]} -eq 0 ]; then
    echo "Файлы для архивации не найдены."
    exit 0
fi

if ((M_FILES > ${#FILES[@]})); then
   M_FILES=${#FILES[@]}
fi
    
echo "Список файлов для переноса в архив:"
printf '%s\n' "${FILES[@]}"

ARCHIVE_NAME="$BACKUP/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
