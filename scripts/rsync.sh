#!/bin/bash

D="/media/sdd"

SF="/sharedfolders"
CMD1="rsync -azvhl --delete --stats"
CMD2="rsync -rpvhl --delete --no-perms --stats"
DIFF="diff -rq --no-dereference"
DATE="date +%Y.%m.%d-%H:%M:%S"
LOG="tee -a $D``1/logs/$($DATE).md"

mkdir -p $D\1/logs
mkdir -p $D\1/_Software
mkdir -p $D\1/OS
mkdir -p $D\1/TimeMachine
mkdir -p $D\1/UserData
mkdir -p $D\1/omvbackup
mkdir -p $D\2/Acronis

LAST_BACKUP="`find $SF/Software/omvbackup/* -ctime -30`"
LAST="`find $SF/Software/omvbackup/* -ctime -30 -printf '%f\n'`"
COPY="`find $D\1/omvbackup\/* -printf '%f\n'`"

echo -e       "# BACK-----Software/_Software----------"  $($DATE) | $LOG
$CMD1 $SF/Software/_Software/ $D\1/_Software/                     | $LOG
echo -e "\n\n\n# BACK---------Software/OS-------------"  $($DATE) | $LOG
$CMD1 $SF/Software/OS/        $D\1/OS/                            | $LOG
echo -e "\n\n\n# BACK---------TimeMachine-------------"  $($DATE) | $LOG
$CMD1 $SF/TimeMachine/        $D\1/TimeMachine/                   | $LOG
echo -e "\n\n\n# BACK-----------UserData--------------"  $($DATE) | $LOG
users=($(ls $SF/UserData))
for user in "${users[@]}"; do
echo -e       "## -----------UserData/$user-----------"  $($DATE) | $LOG
$CMD1 $SF/$user/              $D\1/UserData/$user                 | $LOG
done
echo -e "\n\n\n# BACK------Software/Acronis-----------"  $($DATE) | $LOG
$CMD2 $SF/Software/Acronis/   $D\2/Acronis/                       | $LOG
echo -e "\n\n\n# BACK----------OmvBACKUP--------------"  $($DATE) | $LOG
if [[ "$COPY" != "$LAST" ]]; then
    rm -rf $D\1/omvbackup/*
fi
$CMD1 $LAST_BACKUP            $D\1/omvbackup/                     | $LOG

echo -e "\n\n\n# TEST-----Software/_Software----------"  $($DATE) | $LOG
$DIFF $SF/Software/_Software/ $D\1/_Software/                     | $LOG
echo -e "\n\n\n# TEST---------Software/OS-------------"  $($DATE) | $LOG
$DIFF $SF/Software/OS/        $D\1/OS/                            | $LOG
echo -e "\n\n\n# TEST---------TimeMachine-------------"  $($DATE) | $LOG
$DIFF $SF/TimeMachine/        $D\1/TimeMachine/                   | $LOG
echo -e "\n\n\n# TEST-----------UserData--------------"  $($DATE) | $LOG
for user in "${users[@]}"; do
$DIFF $SF/$user               $D\1/UserData/$user                 | $LOG
done
echo -e "\n\n\n# TEST------Software/Acronis-----------"  $($DATE) | $LOG
$DIFF $SF/Software/Acronis/   $D\2/Acronis/                       | $LOG
echo -e "\n\n\n# ---------------Finished--------------"  $($DATE) | $LOG

echo "Finished"  $($DATE) >> /var/log/backup.log
