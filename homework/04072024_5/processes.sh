#!/bin/bash

# Функция логирования старта и запуска процесса
run_process() {
    local process_id=$1
    local ionice_class=$2
    local log_file=$3

    echo "Starting process $process_id with ionice class $ionice_class..."
    (time ionice -c $ionice_class dd if=/dev/zero of=/tmp/testfile_$process_id bs=1M count=1000 oflag=direct) &> $log_file
    echo "Process $process_id completed."
}

# Файлы логов
LOG1="/tmp/process1.log"
LOG2="/tmp/process2.log"

# Запуск процессов в фоне с разными классами ionice
run_process 1 2 $LOG1 &
pid1=$!

run_process 2 3 $LOG2 &
pid2=$!

# Ждем пока процессы будут завершены
wait $pid1
wait $pid2

# Выводим лог работы по каждому процессу
echo "Log for Process 1:"
cat $LOG1

echo "Log for Process 2:"
cat $LOG2

echo "Done."