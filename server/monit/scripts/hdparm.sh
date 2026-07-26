#!/bin/bash

BACKUP_IN_PROGRESS="/run/backup-weekly-cold.in-progress"

# Функция для проверки состояния диска
check_disk_standby() {
  disk="$1"

  # Проверяем, существует ли устройство
  if [ ! -b "$disk" ]; then
    echo "Error: Device $disk does not exist or is not a block device."
    return 1  # Возвращаем код ошибки
  fi

  # Получаем состояние диска с помощью hdparm
  state=$(hdparm -C "$disk" 2>/dev/null | grep "drive state is" | awk '{print $4}')

  # Проверяем, удалось ли получить состояние
  if [ -z "$state" ]; then
    echo "Error: Could not determine drive state for $disk.  Possible permission or hdparm issue."
    return 1  # Возвращаем код ошибки
  fi

  # Проверяем, находится ли диск в состоянии standby
  if [ "$state" == "standby" ]; then
    echo "$disk is in standby."
    return 0 # Возвращаем код успеха
  else
    echo "$disk is NOT in standby (state: $state)."
    return 1 # Возвращаем код ошибки
  fi
}

# ColdBackup (/dev/sde) штатно активен, пока идёт еженедельный бэкап.
if [ -e "$BACKUP_IN_PROGRESS" ]; then
  echo "Weekly ColdBackup is running; skipping standby check for /dev/sde."
  sde_status=0
else
  check_disk_standby /dev/sde
  sde_status=$?
fi

# Проверка /dev/sde
if [ "$sde_status" -eq 0 ]; then
  echo "/dev/sde is in standby."
  exit 0
else
  echo "/dev/sde is NOT in standby."
  exit -1
fi
