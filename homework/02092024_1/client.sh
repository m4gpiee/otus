#!/bin/bash
sudo su
timedatectl set-timezone Europe/Moscow
#apt update
apt update
apt install mc ntp ntpd -y && systemctl enable ntpd
echo "192.168.56.150    client" >> /etc/hosts
echo "192.168.56.160    backup" >> /etc/hosts
ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
cp /tmp/files/borg-backup.sh /etc/
cp /tmp/files/borg-backup.timer /etc/systemd/system
cp /tmp/files/borg-backup.service /etc/systemd/system
chmod +x /etc/borg-backup.sh
apt install borgbackup -y
useradd -m borg