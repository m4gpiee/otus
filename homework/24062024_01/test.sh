#!/bin/bash

# Задача 1. Создаем пулы RAID1
zpool create otus1 mirror /dev/sdb /dev/sdc
zpool create otus2 mirror /dev/sdd /dev/sde
zpool create otus3 mirror /dev/sdf /dev/sdg
zpool create otus4 mirror /dev/sdh /dev/sda

# Проверяем, что пулы созданы, и выводим информацию
zpool list
zfs get all | grep compression

# Скачиваем файл во все пулы
for i in {1..4}; do 
    wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log
done

# Проверяем, что файл скачан
for i in {1..4}; do 
    if [ -f /otus$i/pg2600.converter.log ]; then
        echo "Файл успешно скачан в otus$i"
    else
        echo "Ошибка скачивания файла в otus$i"
    fi
done

# Проверяем, сколько занимает места один файл и степень сжатия
zfs list
zfs get all | grep compressratio | grep -v ref

# Задача 2. Скачиваем и распаковываем архив
wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download' && tar -xzvf archive.tar.gz

# Импортируем пул
zpool import -d zpoolexport/
zpool import -d zpoolexport/ otus

# Задача 3. Работа со снапшотом

wget -O otus_task2.file --no-check-certificate 'https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download'

# Получаем снимок
zfs receive otus/test@today < otus_task2.file

# Ищем секретное сообщение и выводим его
SECRET_MESSAGE=$(find / -name secret_message 2>/dev/null)
if [ -f "$SECRET_MESSAGE" ]; then
    echo "Секретное сообщение найдено:"
    cat "$SECRET_MESSAGE"
else
    echo "Секретное сообщение не найдено."
fi
