#!/bin/bash

LOG_FILE="/home/art/otus/otus/homework/04072024_4/access-4560-644067.log"
LINES_FILE="/home/art/otus/otus/homework/04072024_4/lines"

# Читаем количество строк из файла, если он существует
if [[ -f "$LINES_FILE" ]]; then
    number=$(cat "$LINES_FILE")
else
    number=0
fi

# Считаем текущее количество строк в лог-файле
currentLines=$(wc -l < "$LOG_FILE")

# Если файл lines не существует или пуст, то создаем его
if [[ -z "$number" || "$number" -eq 0 ]]; then
    number=0
fi

# Определение временных меток
StartTime=$(awk 'NR=='"$((number + 1))"'{print $4 $5}' "$LOG_FILE" | sed 's/[][]//g')
EndTime=$(awk 'NR=='"$currentLines"'{print $4 $5}' "$LOG_FILE" | sed 's/[][]//g')

# Определение количества IP запросов с IP адресов
IP=$(awk 'NR>'"$number"'' "$LOG_FILE" | awk '{print $1}' | sort | uniq -c | sort -rn | awk '{print "Количество запросов:" $1, "IP:" $2}')

# Y количества адресов
addresses=$(awk 'NR>'"$number"' && $9 ~ /200/' "$LOG_FILE" | awk '{print $7}' | sort | uniq -c | sort -rn | awk '{ if ($1 >= 10) { print "Количество запросов:" $1, "URL:" $2 } }')

# Ошибки c момента последнего запуска
errors=$(awk 'NR>'"$number"'' "$LOG_FILE" | cut -d '"' -f3 | cut -d ' ' -f2 | sort | uniq -c | sort -rn)

# Записываем текущее количество строк в файл
echo "$currentLines" > "$LINES_FILE"

# Отправка почты
echo -e "Данные за период: $StartTime - $EndTime\n$IP\n\nЧасто запрашиваемые адреса:\n$addresses\n\nЧастые ошибки:\n$errors" | mail -s "check msg" root@localhost