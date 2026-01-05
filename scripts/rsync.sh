#!/bin/bash

# {{{ HDD names; gen macro
D="/media/backup/"
D1=$(/sbin/blkid -o list | grep 980ea83c-35e0-4ac8-be8e-0883df7131f8 | awk '{print $1}')
D2=$(/sbin/blkid -o list | grep 9f3e98ac-6a53-40dc-ab48-77c3b1df9562 | awk '{print $1}')

SF="/sharedfolders"

# CMD1="echo"
# CMD2="echo"
# DIFF="echo"
# echo "DEBUG_MODE"

CMD1="rsync -azvhl --delete --stats"
CMD2="rsync -rpvhl --delete --no-perms --stats"
DIFF="diff -rq --no-dereference"

DATE="date +%Y.%m.%d-%H:%M:%S"
mkdir -p /var/log/rsync_backup
LOG="tee -a /var/log/rsync_backup/$($DATE).md"

GETOPT () {
    echo -n "Press 'y' to continue: "
    read inp
    if [[ "$inp" == "y" ]]; then inp="";
    elif [[ "$inp" == "n" ]]; then inp=-1;
    else echo; printf "${RED}%s${NC}\n" "ERR: unknown input (y/n)"; echo; GETOPT;
    fi
}
# }}}

# {{{ Get users list
users=($(ls $SF/UserData))
# }}}

D1() {
# {{{ Mount DISK
hdparm -J $D1
# }}} 

# {{{ Check DISK
while [ ! -f $D/d1-p1/.d1-p1 ]; do
    echo "Error: Wrong disk inserted!"                               | $LOG
    echo "Finished"  $($DATE)  "Error: Wrong disk inserted">> /var/log/backup.log
    GETOPT
done
# }}}

# {{{ Create dirs on backup drive
mkdir -p $D/d1-p1/_Software
mkdir -p $D/d1-p1/OS
mkdir -p $D/d1-p1/UserData
mkdir -p $D/d1-p1/omvbackup
# }}}

# {{{ Check free space on backup drive
echo -e "# TEST -------DISK 1 FREE SPACE--------"  $($DATE) | $LOG
DISK_SIZE_1=$(df | grep $D\d1-p1 | awk '{print $2}');

GB=1048576
S=0
# path                                  backup_drive
# /sharedfolders/Software/_Software/    d1
# /sharedfolders/Software/OS/           d1
# /sharedfolders/Software/omvbackup/    d1
# /sharedfolders/UserData/              d1
S1=0
S=$(du -s /sharedfolders/Software/_Software/     | cut -f1); S1=$((S1 + $S))
echo "/sharedfolders/Software/_Software:    " $(($S / GB))  "GB"    | $LOG
S=$(du -s /sharedfolders/Software/OS/            | cut -f1); S1=$((S1 + $S))
echo "/sharedfolders/Software/OS:           " $(($S / GB))  "GB"    | $LOG
S=0; for user in "${users[@]}"; do
    S=$((S + $(du -s /sharedfolders/$user/       | cut -f1)))
done; S1=$((S1 + $S))
echo "/sharedfolders/UserData:              " $(($S / GB))  "GB"    | $LOG
S=$(du -s /sharedfolders/Software/omvbackup/     | cut -f1); S1=$((S1 + $S))
echo "/sharedfolders/Software/omvbackup:    " $(($S / GB))  "GB"    | $LOG

echo "Requred space on drive 1:     " $(($S1 / GB))           "GB"  | $LOG
echo "Drive 1 size:                 " $(($DISK_SIZE_1 / GB))  "GB"  | $LOG
if [ "$S1" -gt "$DISK_SIZE_1" ]; then
    echo "Error: No space on Drive 1"                               | $LOG
    echo "Finished"  $($DATE)  "Error: No space on Drive 1">> /var/log/backup.log
    exit
fi
# }}}

# {{{ Backup
echo -e     "\n# BACK-----Software/_Software----------"  $($DATE) | $LOG
$CMD1 $SF/Software/_Software/ $D/d1-p1/_Software/                     | $LOG
echo -e "\n\n\n# BACK---------Software/OS-------------"  $($DATE) | $LOG
$CMD1 $SF/Software/OS/        $D/d1-p1/OS/                            | $LOG
echo -e "\n\n\n# BACK-----------UserData--------------"  $($DATE) | $LOG
for user in "${users[@]}"; do
echo -e       "## -----------UserData/$user-----------"  $($DATE) | $LOG
$CMD1 $SF/$user/              $D/d1-p1/UserData/$user                 | $LOG
done
echo -e "\n\n\n# BACK----------OmvBACKUP--------------"  $($DATE) | $LOG
$CMD1 $SF/Software/omvbackup/ $D/d1-p1/omvbackup/                     | $LOG
# }}}

# {{{ Test backup
echo -e "\n\n\n# TEST-----Software/_Software----------"  $($DATE) | $LOG
$DIFF $SF/Software/_Software/ $D/d1-p1/_Software/                     | $LOG
echo -e "\n\n\n# TEST---------Software/OS-------------"  $($DATE) | $LOG
$DIFF $SF/Software/OS/        $D/d1-p1/OS/                            | $LOG
echo -e "\n\n\n# TEST-----------UserData--------------"  $($DATE) | $LOG
for user in "${users[@]}"; do
echo -e       "## -----------UserData/$user-----------"  $($DATE) | $LOG
$DIFF $SF/$user               $D/d1-p1/UserData/$user                 | $LOG
done
# }}}

# {{{ Umount DISK
hdparm -Y $D1
# }}} 
}

D2(){
# {{{ Mount DISK
hdparm -J $D2
# }}} 

# {{{ Check DISK
while [ ! -f $D/d2-p1/.d2-p1 ]; do
    echo "Error: Wrong disk inserted (p1)!"                           | $LOG
    echo "Finished"  $($DATE)  "Error: Wrong disk inserted">> /var/log/backup.log
    GETOPT
done
while [ ! -f $D/d2-p2/.d2-p2 ]; do
    echo "Error: Wrong disk inserted (p2)!"                           | $LOG
    echo "Finished"  $($DATE)  "Error: Wrong disk inserted">> /var/log/backup.log
    GETOPT
done
# }}}

# {{{ Create dirs on backup drive
mkdir -p $D/d2-p1/TimeMachine
mkdir -p $D/d2-p2/Acronis
# }}}

# {{{ Check free space on backup drive
echo -e "# TEST -------DISK 2 FREE SPACE--------"  $($DATE) | $LOG
DISK_SIZE_1=$(df | grep $D\d2-p1 | awk '{print $2}');
DISK_SIZE_2=$(df | grep $D\d2-p2 | awk '{print $2}');

GB=1048576
S=0
# path                                  backup_drive
# /sharedfolders/TimeMachine/           d1
# /sharedfolders/Software/Acronis/      d2

S1=0
S=$(du -s /sharedfolders/TimeMachine/            | cut -f1); S1=$((S1 + $S))
echo "/sharedfolders/TimeMachine:           " $(($S / GB))  "GB"    | $LOG
echo "Requred space on drive 1:     " $(($S1 / GB))           "GB"  | $LOG
echo "Drive 1 size:                 " $(($DISK_SIZE_1 / GB))  "GB"  | $LOG
if [ "$S1" -gt "$DISK_SIZE_1" ]; then
    echo "Error: No space on Drive 1"                               | $LOG
    echo "Finished"  $($DATE)  "Error: No space on Drive 1">> /var/log/backup.log
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
echo -e "\n\n\n# BACK---------TimeMachine-------------"  $($DATE) | $LOG
$CMD1 $SF/TimeMachine/        $D/d2-p1/TimeMachine/                   | $LOG
echo -e "\n\n\n# BACK------Software/Acronis-----------"  $($DATE) | $LOG
$CMD2 $SF/Software/Acronis/   $D/d2-p2/Acronis/                       | $LOG
# }}}

# {{{ Test backup
echo -e "\n\n\n# TEST---------TimeMachine-------------"  $($DATE) | $LOG
$DIFF $SF/TimeMachine/        $D/d2-p1/TimeMachine/                   | $LOG
echo -e "\n\n\n# TEST------Software/Acronis-----------"  $($DATE) | $LOG
$DIFF $SF/Software/Acronis/   $D/d2-p2/Acronis/                       | $LOG
# }}}

# {{{ Umount DISK
hdparm -Y $D2
# }}} 
}

D1
D2

# {{{ Finish
echo -e "\n\n\n# ---------------Finished--------------"  $($DATE) | $LOG
echo "Finished"  $($DATE) >> /var/log/backup.log
# }}}

