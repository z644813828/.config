#!/bin/bash

# {{{ HDD names; gen macro
D="/media/sdd"

SF="/sharedfolders"
CMD1="rsync -azvhl --delete --stats"
CMD2="rsync -rpvhl --delete --no-perms --stats"
DIFF="diff -rq --no-dereference"
DATE="date +%Y.%m.%d-%H:%M:%S"
LOG="tee -a $D``1/logs/$($DATE).md"
# }}}

# {{{ Create dirs on backup drive
mkdir -p $D\1/logs
mkdir -p $D\1/_Software
mkdir -p $D\1/OS
mkdir -p $D\1/TimeMachine
mkdir -p $D\1/UserData
mkdir -p $D\1/omvbackup
mkdir -p $D\2/Acronis
# }}}

# {{{ Get last omvbackup file; users list
LAST_BACKUP="`find $SF/Software/omvbackup/* -ctime -30`"
LAST="`find $SF/Software/omvbackup/* -ctime -30 -printf '%f\n'`"
COPY="`find $D\1/omvbackup\/* -printf '%f\n'`"
users=($(ls $SF/UserData))
# }}}

# {{{ Check free space on backup drives
echo -e "# TEST --------DISK FREE SPACE---------"  $($DATE) | $LOG
DISK_SIZE_1=$(df | grep $D\1 | awk '{print $2}');
DISK_SIZE_2=$(df | grep $D\2 | awk '{print $2}');

GB=1048576
S=0
# path                                  backup_drive
# /sharedfolders/Software/_Software/    d1
# /sharedfolders/Software/OS/           d1
# /sharedfolders/TimeMachine/           d1
# /sharedfolders/UserData/              d1
# /sharedfolders/Software/omvbackup/    d1
# /sharedfolders/Software/Acronis/      d2

S1=0
S=$(du -s /sharedfolders/Software/_Software/     | cut -f1); S1=$((S1 + $S))
echo "/sharedfolders/Software/_Software:    " $(($S / GB))  "GB"    | $LOG
S=$(du -s /sharedfolders/Software/OS/            | cut -f1); S1=$((S1 + $S))
echo "/sharedfolders/Software/OS:           " $(($S / GB))  "GB"    | $LOG
S=$(du -s /sharedfolders/TimeMachine/            | cut -f1); S1=$((S1 + $S))
echo "/sharedfolders/TimeMachine:           " $(($S / GB))  "GB"    | $LOG
S=0; for user in "${users[@]}"; do
    S=$((S + $(du -s /sharedfolders/$user/       | cut -f1)))
done; S1=$((S1 + $S))
echo "/sharedfolders/UserData:              " $(($S / GB))  "GB"    | $LOG
S=0; for back in ${LAST_BACKUP[*]}; do
    S=$((S + $(du -s $back                       | cut -f1)))
done; S1=$((S1 + $S))
echo "/sharedfolders/Software/omvbackup:    " $(($S / GB))  "GB"    | $LOG

echo "Requred space on drive 1:     " $(($S1 / GB))           "GB"  | $LOG
echo "Drive 1 size:                 " $(($DISK_SIZE_1 / GB))  "GB"  | $LOG
if [ "$S1" -gt "$DISK_SIZE_1" ]; then
    echo "Error: No space on Drive 1"                               | $LOG
    echo "Finished"  $($DATE)  "Error: No space on Drive 2">> /var/log/backup.log
    exit
fi

echo ""
S2=0
S=$(du -s /sharedfolders/Software/Acronis        | cut -f1); S2=$((S2 + $S))
echo "/sharedfolders/Software/Acronis:      " $(($S / GB))  "GB"    | $LOG
echo "Requred space on drive 2:     " $(($S2 / GB))           "GB"  | $LOG
echo "Drive 2 size:                 " $(($DISK_SIZE_2 / GB))  "GB"  | $LOG
if [ "$S2" -gt "$DISK_SIZE_2" ]; then
    echo "Error: No space on Drive 2"                               | $LOG
    echo "Finished"  $($DATE)  "Error: No space on Drive 2">> /var/log/backup.log
    exit
fi
# }}}

# {{{ Backup
echo -e     "\n# BACK-----Software/_Software----------"  $($DATE) | $LOG
$CMD1 $SF/Software/_Software/ $D\1/_Software/                     | $LOG
echo -e "\n\n\n# BACK---------Software/OS-------------"  $($DATE) | $LOG
$CMD1 $SF/Software/OS/        $D\1/OS/                            | $LOG
echo -e "\n\n\n# BACK---------TimeMachine-------------"  $($DATE) | $LOG
$CMD1 $SF/TimeMachine/        $D\1/TimeMachine/                   | $LOG
echo -e "\n\n\n# BACK-----------UserData--------------"  $($DATE) | $LOG
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
# }}}

# {{{ Test backup
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
# }}}

# {{{ Finish
echo "Finished"  $($DATE) >> /var/log/backup.log
# }}}
