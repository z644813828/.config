#!/bin/bash

set -euxo pipefail

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

# Function to process a single folder
process_folder() {
  local folder="$1"
  local zip_file="$TARGET_DIR/${DATE}_$(basename "$folder").zip" # Archive name based on folder name and date

  # Check if the source folder exists
  if [ ! -d "$folder" ]; then
    echo "Error: Source folder '$folder' does not exist."
    return 1  # Error code for the function
  fi

  # Compress the folder into a ZIP archive, preserving symbolic links
  zip -ryqq "$zip_file" "$folder"

  # Check if the compression was successful
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create ZIP archive '$zip_file' for folder '$folder'."
    return 1 
  fi

  # Transfer the archive via SCP
  scp "$zip_file" "server:~/Документы/backup/"

  # Check if the transfer was successful
  if [ $? -ne 0 ]; then
    echo "Error: Failed to transfer archive '$zip_file' via SCP for folder '$folder'."
    return 1 
  fi

  rm "$zip_file"

  return 0
}

# copy relevant folders to iCloud
cp -r "$HOME/.ssh" "$ICLOUD_PATH/Backup/"
cp -r "$HOME/Documents/VPN" "$ICLOUD_PATH/Backup/"

# copy all listed folders to server
for folder in "${SOURCE_FOLDERS[@]}"; do
  echo "Processing folder: $folder"
  process_folder "$folder"

  if [ $? -ne 0 ]; then
    echo "Error processing folder '$folder'.  Continuing..."
  fi
done

ssh -Xt server "echo (date) > ~/Документы/backup/date"

echo "All folders processed."

exit 0
