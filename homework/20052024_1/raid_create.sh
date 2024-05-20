#!/bin/bash

# Объявление дисков
disks="/dev/sd{b,c,d,e,f}"

# Обнуление суперблоков
for disk in $(eval echo $disks); do
    /sbin/mdadm --zero-superblock --force $disk || { echo "Ошибка при обнулении суперблока $disk"; exit 1; }
done

# Создание RAID6 массива
/sbin/mdadm --create --verbose /dev/md0 --level=6 --raid-devices=5 $disks || { echo "Ошибка при создании RAID массива"; exit 1; }

# Создание файла конфигурации mdadm
mkdir -p /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf

# Добавление информации о массиве в конфигурационный файл
/sbin/mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf || { echo "Ошибка при обновлении конфигурации mdadm"; exit 1; }

# Разметка диска
/sbin/parted -s /dev/md0 mklabel gpt || { echo "Ошибка при создании метки диска"; exit 1; }

# Создание разделов
/sbin/parted /dev/md0 mkpart primary ext4 0% 20% || { echo "Ошибка при создании первого раздела"; exit 1; }
/sbin/parted /dev/md0 mkpart primary ext4 20% 40% || { echo "Ошибка при создании второго раздела"; exit 1; }
/sbin/parted /dev/md0 mkpart primary ext4 40% 60% || { echo "Ошибка при создании третьего раздела"; exit 1; }
/sbin/parted /dev/md0 mkpart primary ext4 60% 80% || { echo "Ошибка при создании четвертого раздела"; exit 1; }
/sbin/parted /dev/md0 mkpart primary ext4 80% 100% || { echo "Ошибка при создании пятого раздела"; exit 1; }

# Форматирование разделов в ext4
for i in $(seq 1 5); do
    /sbin/mkfs.ext4 /dev/md0p$i || { echo "Ошибка при форматировании раздела /dev/md0p$i"; exit 1; }
done

# Создание точек монтирования
mkdir -p /raid/part{1,2,3,4,5}

# Монтирование разделов
for i in $(seq 1 5); do
    mount /dev/md0p$i /raid/part$i || { echo "Ошибка при монтировании раздела /dev/md0p$i"; exit 1; }
done

echo "RAID массив успешно создан и разделы смонтированы."
