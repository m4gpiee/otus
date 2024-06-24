#!/bin/bash

check_cmd() {
    if [ $? -ne 0 ]; then
        echo "Команда $1 завершилась неудачно. Прерывание скрипта."
        exit 1
    fi
}


# Обновляем пакетный менеджер и устанавливаем nfs-utils
yum install -y nfs-utils


# Включаем и запускаем firewalld
systemctl enable firewalld --now
systemctl start firewalld
check_cmd "systemctl start firewalld"

# Проверяем статус firewalld
sudo systemctl status firewalld

# Настраиваем правила firewall для NFS
firewall-cmd --add-service="nfs3" --permanent
firewall-cmd --add-service="rpc-bind" --permanent
firewall-cmd --add-service="mountd" --permanent
firewall-cmd --add-port=111/udp --permanent
firewall-cmd --add-port=2049/udp --permanent
firewall-cmd --zone=public --add-service=nfs --permanent

# Применяем изменения в firewall
firewall-cmd --reload

# Включаем и запускаем nfs-server
systemctl enable nfs-server
systemctl start nfs-server
check_cmd "start nfs-server"

# Создаем директорию для общего доступа и устанавливаем права
mkdir -p /srv/share/upload
chown -R nfsnobody:nfsnobody /srv/share
chmod 0777 /srv/share/upload

# Добавляем директорию в экспортируемые ресурсы NFS
echo '/srv/share 192.168.50.11(rw,sync,root_squash,all_squash)' | sudo tee /etc/exports.d/srv_share.exports

# Перезапускаем nfs-server
systemctl restart nfs-server && systemctl status nfs-server
