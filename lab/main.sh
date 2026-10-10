#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Использование: $0 <путь_к_папке> <порог_размера_КБ> <процент_N> <кол_во_файлов_M>"
    exit 1
fi

FOLDER="$1"
THRESHOLD=$2
PERCENT=$3
M_FILES=$4

if [ ! -d "$FOLDER" ]; then
    echo "Ошибка: Указанная папка не существует."
    exit 1
fi

CURRENT_SIZE=$(du -s "$FOLDER" | cut -f1)
echo "Текущий размер папки: ${CURRENT_SIZE} КБ"

CRITICAL_SIZE=$(( THRESHOLD * PERCENT / 100 ))
echo "Критический порог (${PERCENT}% от ${THRESHOLD} КБ): ${CRITICAL_SIZE} КБ"

if [ "$CURRENT_SIZE" -gt "$CRITICAL_SIZE" ]; then
    echo "Внимание: Превышен лимит! Начинается архивация старых файлов."
    
    mkdir -p /backup

    mapfile -t FILES < <(find "$FOLDER" -type f -printf '%T+ %p\n' | sort | head -n "$M_FILES" | cut -d' ' -f2-)
    
    if [ ${#FILES[@]} -eq 0 ]; then
        echo "Файлы для архивации не найдены."
        exit 0
    fi
    
    echo "Список файлов для переноса в архив:"
    printf '%s\n' "${FILES[@]}"

    ARCHIVE_NAME="/backup/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$ARCHIVE_NAME" "${FILES[@]}"
    
    echo "Успех! Архив сохранен в: $ARCHIVE_NAME"
else
    echo "Объем папки находится в пределах нормы."
fi
