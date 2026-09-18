#!/bin/bash

FILE="/srv/dev-disk-by-label-UserData/dmitriy/Документы/backup/date"

# No check is required before the 3rd day of the month
if [ "$(date +%d)" -lt 3 ]; then
    exit 0
fi

if [ ! -f "$FILE" ]; then
    echo "ERROR: Backup has not been performed this month" >&2
    exit 1
fi

file_month=$(date -d "$(cat "$FILE")" +%Y-%m 2>/dev/null) || {
    echo "ERROR: Invalid date in $FILE" >&2
    exit 1
}

if [ "$file_month" != "$(date +%Y-%m)" ]; then
    echo "ERROR: Backup has not been performed this month" >&2
    exit 1
fi

