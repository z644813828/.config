#!/bin/bash

set -euo pipefail

VERBOSE=0
DO_CREATE=0
DO_UPLOAD=0
TARGET_DIR="/tmp"  # Directory for local archives

usage() {
  cat >&2 <<EOF
Usage: $0 [-v] [-c] [-u] [-d DIR]
  -c       only create ZIP archives locally (do not upload)
  -u       only upload existing local ZIP archives to the server
  -d DIR   directory for local archives (default: $TARGET_DIR)
  -v       verbose output
Without -c/-u both steps are performed: create archives, then upload them.
EOF
  exit 2
}

while getopts ":vcud:" opt; do
  case "$opt" in
    v) VERBOSE=1 ;;
    c) DO_CREATE=1 ;;
    u) DO_UPLOAD=1 ;;
    d) TARGET_DIR="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

# Default: do everything
if [ "$DO_CREATE" -eq 0 ] && [ "$DO_UPLOAD" -eq 0 ]; then
  DO_CREATE=1
  DO_UPLOAD=1
fi

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
DATE=$(date +%Y_%m_%d) # Get the current date in YYYY_MM_DD format
REMOTE_HOST="server"
REMOTE_BACKUP_PATH='~/Документы/backup'
REMOTE_BACKUP="$REMOTE_HOST:$REMOTE_BACKUP_PATH/"
RSYNC_RESUME_ARGS=(--partial)

if [ "$DO_UPLOAD" -eq 1 ]; then
  if rsync --help 2>&1 | grep -q -- '--append-verify'; then
    RSYNC_RESUME_ARGS+=(--append-verify)
  elif rsync --help 2>&1 | grep -q -- '--append'; then
    RSYNC_RESUME_ARGS+=(--append)
  fi
fi

mkdir -p "$TARGET_DIR"

# Check that the archive exists on the server and is valid
remote_zip_valid() {
  local zip_name="$1"
  ssh -T "$REMOTE_HOST" "sh -lc 'remote_zip=\"\$HOME/Документы/backup/$zip_name\"; test -f \"\$remote_zip\" && zip -Tq \"\$remote_zip\"'"
}

# Create (or reuse) a local ZIP archive for a folder
create_archive() {
  local folder="$1"
  local zip_file="$2"
  local partial_zip_file="$zip_file.partial"

  if [ ! -d "$folder" ]; then
    echo "Error: Source folder '$folder' does not exist."
    return 1
  fi

  if [ -f "$zip_file" ]; then
    if zip -Tq "$zip_file"; then
      echo "Using existing ZIP archive: $zip_file"
      return 0
    fi
    echo "Warning: Existing ZIP archive is invalid, recreating: $zip_file"
    rm -f "$zip_file"
  fi

  rm -f "$partial_zip_file"

  # Compress the folder into a ZIP archive, preserving symbolic links.
  zip -ryqq "$partial_zip_file" "$folder"

  if ! zip -Tq "$partial_zip_file"; then
    echo "Error: Failed to create valid ZIP archive '$zip_file' for folder '$folder'."
    rm -f "$partial_zip_file"
    return 1
  fi

  mv "$partial_zip_file" "$zip_file"
  echo "Created ZIP archive: $zip_file"
  return 0
}

# Upload a local ZIP archive to the server, verify it and remove the local copy
upload_archive() {
  local folder="$1"
  local zip_file="$2"
  local zip_name="$3"

  if [ ! -f "$zip_file" ]; then
    echo "Error: Local ZIP archive '$zip_file' not found for folder '$folder'. Run with -c first."
    return 1
  fi

  if ! zip -Tq "$zip_file"; then
    echo "Error: Local ZIP archive '$zip_file' is invalid, not uploading."
    return 1
  fi

  # Transfer the archive. New rsync versions use --append-verify; macOS system
  # rsync 2.6.9 falls back to --append and the remote zip test below.
  if ! rsync -P "${RSYNC_RESUME_ARGS[@]}" "$zip_file" "$REMOTE_BACKUP"; then
    echo "Error: Failed to transfer archive '$zip_file' via rsync for folder '$folder'."
    return 1
  fi

  if ! remote_zip_valid "$zip_name"; then
    echo "Error: Remote ZIP archive failed validation after transfer: $zip_name"
    return 1
  fi

  rm "$zip_file"
  echo "Uploaded and removed local archive: $zip_file"
  return 0
}

# Process a single folder according to the selected mode
process_folder() {
  local folder="$1"
  local zip_name="${DATE}_$(basename "$folder").zip"
  local zip_file="$TARGET_DIR/$zip_name"

  # If we are going to upload anyway, skip everything when the server already has it
  if [ "$DO_UPLOAD" -eq 1 ] && remote_zip_valid "$zip_name"; then
    echo "Remote ZIP archive already exists and is valid, skipping: $zip_name"
    rm -f "$zip_file" "$zip_file.partial"
    return 0
  fi

  if [ "$DO_CREATE" -eq 1 ]; then
    create_archive "$folder" "$zip_file" || return 1
  fi

  if [ "$DO_UPLOAD" -eq 1 ]; then
    upload_archive "$folder" "$zip_file" "$zip_name" || return 1
  fi

  return 0
}

# copy relevant folders to iCloud (only when creating backups)
if [ "$DO_CREATE" -eq 1 ]; then
  mkdir -p "$ICLOUD_PATH/Backup/ssh" "$ICLOUD_PATH/Backup/VPN"
  rsync -a --delete "$HOME/.ssh/" "$ICLOUD_PATH/Backup/ssh/"
  rsync -a --delete "$HOME/Documents/VPN/" "$ICLOUD_PATH/Backup/VPN/"
fi

ALL_SUCCESS=1

# process all listed folders
for folder in "${SOURCE_FOLDERS[@]}"; do
  echo "Processing folder: $folder"

  if [ "$DO_CREATE" -eq 1 ] && [ -d "$folder" ]; then
    du -hs "$folder"
  fi

  if ! process_folder "$folder"; then
    echo "Error processing folder '$folder'. Continuing..."
    ALL_SUCCESS=0
  fi
done

if [ "$DO_UPLOAD" -eq 1 ]; then
  if [ "$ALL_SUCCESS" -eq 1 ]; then
    ssh -T "$REMOTE_HOST" \
      "sh -lc 'date > \"\$HOME/Документы/backup/date\"'"
    echo "All archives uploaded successfully. Backup date updated."
  else
    echo "Some archives failed. Backup date was NOT updated."
  fi
fi

echo "All folders processed."

if [ "$ALL_SUCCESS" -eq 1 ]; then
  exit 0
else
  exit 1
fi
