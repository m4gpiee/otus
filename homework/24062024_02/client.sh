#!/bin/bash

check_cmd() {
    if [ $? -ne 0 ]; then
        echo "Команда $1 завершилась неудачно. Прерывание скрипта."
        exit 1
    fi
}


# Установить необходимые пакеты
yum install -y nfs-utils
check_cmd "yum install -y nfs-utils"

# Включить и запустить firewalld
systemctl enable firewalld --now

# Проверить статус firewalld
systemctl status firewalld

# Добавить строку в /etc/fstab для монтирования NFS
echo "192.168.50.10:/srv/share/ /mnt nfs _netdev,vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab

# Перезагрузить демоны systemd
systemctl daemon-reload

# Перезапустить удаленные файловые системы
systemctl restart remote-fs.target
check_cmd "systemctl restart remote-fs.target"