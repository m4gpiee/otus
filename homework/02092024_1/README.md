Для выполнения данного задания необходимо создать две VM:
VM1: client, на нем будет настроена периодическая отправка бекапа
VM2: backup, машина,на которую отправляются бекапы

В Vagrantfile:
передача файлов из директории files в директорию /tmp на созданной VM;
прописаны post install скрипты которые позволяют следующее:


VM1:
- Установка ntp, ntpdate, borgbackup;
- Создания ключевой пары;
- Добавления обоих ВМ в /etc/hosts;
- Копирования в соответствующие директории таймера, юнита службы, скрипта выполняющего бекап;
- Присвоения разрешений на исполнение;
- Добавление пользователя.

VM2:
- Установка ntp, ntpdate, borgbackup;
- Cоздания директории /opt/backup/ и назначение на неё прав;
- Добавления обоих ВМ в /etc/hosts;
- Добавление пользователя.

Сгенерированный pubkey от VM1 для пользователя borg необходимо вручную передать на машину VM2 и перезапустить сервис SSH.


# Инициализируем репозиторий borg на backup сервере с client сервера:
borg init --encryption=repokey borg@192.168.56.160:/opt/backup
# Запускаем для проверки бекапа:
borg create --stats --list borg@192.168.56.160:/opt/backup/::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
# Проверяем:
$ borg list borg@192.168.56.160:/opt/backup
etc-2024-10-06_15:43:31              Sun, 2024-10-06 15:43:32 [0589a7b0154ffd7e1fb151e7433d8680aeb7e5edfb770e5631824319a55aeb35]
$ borg list borg@192.168.56.160:/opt/backup::etc-2024-10-06_15:43:31
drwxr-xr-x root   root          0 Sun, 2024-10-06 15:30:05 etc
lrwxrwxrwx root   root         19 Fri, 2024-02-16 21:44:26 etc/mtab -> ../proc/self/mounts
lrwxrwxrwx root   root         21 Wed, 2024-02-14 17:47:50 etc/os-release -> ../usr/lib/os-release
lrwxrwxrwx root   root         39 Fri, 2024-02-16 21:44:25 etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf
lrwxrwxrwx root   root         13 Tue, 2023-12-05 08:15:51 etc/rmt -> /usr/sbin/rmt
lrwxrwxrwx root   root         23 Fri, 2024-02-16 21:46:20 etc/vtrgb -> /etc/alternatives/vtrgb
drwxr-xr-x root   root          0 Fri, 2024-02-16 21:51:28 etc/ModemManager
...
# Достаем файл из бекапа:
$ borg extract borg@192.168.56.160:/opt/backup/::etc-2024-10-06_15:43:31 etc/hostname
$ pwd
/var/backup
$ ll 
-sh: 19: ll: not found
$ ls -la
total 12
drwxr-xr-x  3 borg borg 4096 Oct  6 15:48 .
drwxr-xr-x 13 root root 4096 Oct  6 13:42 ..
drwx------  2 borg borg 4096 Oct  6 15:48 etc
-rw-rw-r--  1 borg borg    0 Oct  6 15:41 file1
-rw-rw-r--  1 borg borg    0 Oct  6 15:41 file2
-rw-rw-r--  1 borg borg    0 Oct  6 15:41 file3
$ pwd 
/var/backup
$ cat etc/hostname
client
$ exit


# Процесс создания бекапов автоматизирован с помощью systemd. 
cat /etc/systemd/system/borg-backup.service
[Unit]
Description=Automated Borg Backup
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/borg-backup.sh

[Install]
WantedBy=multi-user.target


cat /etc/borg-backup.sh 
#!/usr/bin/env bash
# the envvar $REPONAME is something you should just hardcode

export REPOSITORY="borg@192.168.56.160:/opt/backup"


# Fill in your password here, borg picks it up automatically
export BORG_PASSPHRASE="borg"

# Backup all of /home except a few excluded directories and files
borg create -v --stats --compression lz4                 \
    $REPOSITORY::'{hostname}-{now:%Y-%m-%d_%H:%M:%S}' /etc \

# Route the normal process logging to journalctl
2>&1

# If there is an error backing up, reset password envvar and exit
if [ "$?" = "1" ] ; then
    export BORG_PASSPHRASE=""
    exit 1
fi

 Prune the repo of extra backups
borg prune -v $REPOSITORY --prefix '{hostname}-'         \
    --keep-minutely=120                                  \
    --keep-daily=90                                       \
    --keep-monthly=12                                     \
    --keep-yearly=1                                     \

borg list $REPOSITORY

# Unset the password
export BORG_PASSPHRASE=""
exit



# Проверку работы можно выполнить следующим образом:
$ borg list borg@192.168.56.160:/opt/backup
etc-2024-10-06_15:43:31              Sun, 2024-10-06 15:43:32 [0589a7b0154ffd7e1fb151e7433d8680aeb7e5edfb770e5631824319a55aeb35]
client-2024-10-06_16:00:10           Sun, 2024-10-06 16:00:11 [b35bed3f22945e1ddce7c55daf494cf99ea8458f98c711ae308dc7d3d9b74adf]
client-2024-10-06_16:00:55           Sun, 2024-10-06 16:01:02 [bb894ab0a48ec311bf913bc8190b09d61484508b5574586bfff20e1d423f7335]
$ exit
vagrant@client:/etc$ systemctl list-timers --all | grep borg
Sun 2024-10-06 16:05:00 MSK 3min 8s left  Sun 2024-10-06 16:00:03 MSK 1min 47s ago         borg-backup.timer            borg-backup.service

Дополнительно, в репозиторий включены скриншоты.