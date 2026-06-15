#!/bin/bash

set -euo pipefail

VERBOSE=0

while getopts ":v" opt; do
  case "$opt" in
    v)
      VERBOSE=1
      ;;
    \?)
      echo "Usage: $0 [-v]" >&2
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))

if [ "$VERBOSE" -eq 1 ]; then
  set -x
fi

ICLOUD_PATH="/Users/dmitriy/Library/Mobile Documents/com~apple~CloudDocs"

SOURCE_FOLDERS=(
  "$ICLOUD_PATH"

  "$HOME/Documents/Documents"
  "$HOME/Documents/Libs"
  "$HOME/Documents/Projects"
  "$HOME/Documents/VPN"
)

# General parameters
TARGET_DIR="/tmp"  # Directory to create temporary archives
DATE=$(date +%Y_%m_%d) # Get the current date in YYYY.MM.DD format
REMOTE_HOST="server"
REMOTE_BACKUP_PATH='~/Документы/backup'
REMOTE_BACKUP="$REMOTE_HOST:$REMOTE_BACKUP_PATH/"
RSYNC_RESUME_ARGS=(--partial)

if rsync --help 2>&1 | grep -q -- '--append-verify'; then
  RSYNC_RESUME_ARGS+=(--append-verify)
elif rsync --help 2>&1 | grep -q -- '--append'; then
  RSYNC_RESUME_ARGS+=(--append)
fi

# Function to process a single folder
process_folder() {
  local folder="$1"
  local zip_name="${DATE}_$(basename "$folder").zip"
  local zip_file="$TARGET_DIR/$zip_name" # Archive name based on folder name and date
  local partial_zip_file="$zip_file.partial"

  # Check if the source folder exists
  if [ ! -d "$folder" ]; then
    echo "Error: Source folder '$folder' does not exist."
    return 1  # Error code for the function
  fi

  if ssh -T "$REMOTE_HOST" "sh -lc 'remote_zip=\"\$HOME/Документы/backup/$zip_name\"; test -f \"\$remote_zip\" && zip -Tq \"\$remote_zip\"'"; then
    echo "Remote ZIP archive already exists and is valid, skipping: $zip_name"
    rm -f "$zip_file" "$partial_zip_file"
    return 0
  fi

  if [ -f "$zip_file" ]; then
    if zip -Tq "$zip_file"; then
      echo "Using existing ZIP archive: $zip_file"
    else
      echo "Warning: Existing ZIP archive is invalid, recreating: $zip_file"
      rm -f "$zip_file"
    fi
  fi

  if [ ! -f "$zip_file" ]; then
    rm -f "$partial_zip_file"

    # Compress the folder into a ZIP archive, preserving symbolic links.
    zip -ryqq "$partial_zip_file" "$folder"

    # Check if the compression was successful and the archive is readable.
    if ! zip -Tq "$partial_zip_file"; then
      echo "Error: Failed to create valid ZIP archive '$zip_file' for folder '$folder'."
      rm -f "$partial_zip_file"
      return 1
    fi

    mv "$partial_zip_file" "$zip_file"
  fi

  # Transfer the archive. New rsync versions use --append-verify; macOS system
  # rsync 2.6.9 falls back to --append and the remote zip test below.
  if ! rsync -P "${RSYNC_RESUME_ARGS[@]}" "$zip_file" "$REMOTE_BACKUP"; then
    echo "Error: Failed to transfer archive '$zip_file' via SCP for folder '$folder'."
    return 1
  fi

  if ! ssh -T "$REMOTE_HOST" "sh -lc 'remote_zip=\"\$HOME/Документы/backup/$zip_name\"; test -f \"\$remote_zip\" && zip -Tq \"\$remote_zip\"'"; then
    echo "Error: Remote ZIP archive failed validation after transfer: $zip_name"
    return 1
  fi

  rm "$zip_file"

  return 0
}

# copy relevant folders to iCloud
mkdir -p "$ICLOUD_PATH/Backup/ssh" "$ICLOUD_PATH/Backup/VPN"
rsync -a --delete "$HOME/.ssh/" "$ICLOUD_PATH/Backup/ssh/"
rsync -a --delete "$HOME/Documents/VPN/" "$ICLOUD_PATH/Backup/VPN/"

# copy all listed folders to server
for folder in "${SOURCE_FOLDERS[@]}"; do
  echo "Processing folder: $folder"
  du -hs "$folder"
  if ! process_folder "$folder"; then
    echo "Error processing folder '$folder'.  Continuing..."
  fi
done

ssh -T "$REMOTE_HOST" "sh -lc 'date > \"\$HOME/Документы/backup/date\"'"

echo "All folders processed."

exit 0
