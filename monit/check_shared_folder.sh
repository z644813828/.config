#!/bin/bash
MD5_FILE="/tmp/shared_folder"
SHARED_FOLDER="/sharedfolders/temp_folder/download_link"
LINK_FOLDER="/var/www/openmediavault/shared"

md5=$(checksumdir $SHARED_FOLDER)
last_md5=$(tail -n 1 $MD5_FILE)
if [[ $last_md5 != $md5 ]]; then
    echo $md5 >> $MD5_FILE
    ln -sf ${SHARED_FOLDER}/* $LINK_FOLDER/
    exit 1;
else
    exit 0;
fi

