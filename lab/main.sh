#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Using: $0 <directory_with_logs> <prosent> <number_of_old_files> <directory_with_archive>"
    exit 1
fi

FOLDER="$1"
THRESHOLD="$2"
M_FILES="$3"
BACKUP="$4"

if [ ! -d "$FOLDER" ]; then
    echo "Error: The specified folder does not exist."
    exit 1
fi

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || \
   (( THRESHOLD < 1 || THRESHOLD > 100 )); then
    echo "Error: the threshold must be an integer from 1 to 100."
    exit 1
fi

if ! [[ "$M_FILES" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: the number of files must be a positive number."
    exit 1
fi

CURRENT_SIZE=$(du -s "$FOLDER" | cut -f1)
echo "Current folder size: ${CURRENT_SIZE} КB"
FOLDER_THRESHOLD=1024 #KB

USAGE_PERCENT=$(( CURRENT_SIZE * 100 / FOLDER_THRESHOLD ))
echo "Current occupancy as a percentage: ${USAGE_PERCENT}%"
echo "Threshold: ${THRESHOLD}%"

if (( USAGE_PERCENT <= THRESHOLD )); then
    echo "The threshold has not been exceeded. Archiving is not required.."
    exit 0
fi

echo "Attention: Limit exceeded! Archiving of old files is beginning."

mapfile -t FILES < <(find "$FOLDER" -maxdepth 1 -type f -printf '%T@ %p\n' |sort -n | cut -d' ' -f2-)
    
if [ ${#FILES[@]} -eq 0 ]; then
    echo "No files found for archiving."
    exit 0
fi

if ((M_FILES > ${#FILES[@]})); then
   M_FILES=${#FILES[@]}
fi
    
echo "List of files suitable for moving to the archive:"
printf '%s\n' "${FILES[@]}"

mkdir -p "$BACKUP"

if ! mkdir -p "$BACKUP"; then
    echo "Error: unable to create directory '$BACKUP'."
    exit 1
fi

ARCHIVE_NAME="$BACKUP/backup_$(date +%Y%m%d_%H%M%S).tar.gz"

SELECTED_FILES=()

for (( i=0; i<M_FILES; i++ )); do
    SELECTED_FILES+=("$(basename "${FILES[$i]}")")
done

if (( ${#SELECTED_FILES[@]} == 0 )); then
    echo "No files to archive."
    exit 0
fi

echo "The following files will be archived:"
for file in "${SELECTED_FILES[@]}"; do
    echo "  $file"
done

if tar -czf "$ARCHIVE_NAME" -C "$FOLDER" "${SELECTED_FILES[@]}"; then
    echo "Success! Archive saved in: $ARCHIVE_NAME"
else
    echo "Error creating archive."
    exit 1
fi

exit 0
