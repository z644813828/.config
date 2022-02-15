#!/bin/bash

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

# Проверяем /dev/sda
check_disk_standby /dev/sda
sda_status=$?

# Проверяем /dev/sdb
check_disk_standby /dev/sdb
sdb_status=$?

# Общая проверка
if [ "$sda_status" -eq 0 ] && [ "$sdb_status" -eq 0 ]; then
  echo "Both /dev/sda and /dev/sdb are in standby."
  exit 0
else
  echo "At least one of /dev/sda and /dev/sdb is NOT in standby."
  exit -1
fi
