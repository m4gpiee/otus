#!/bin/bash
sudo su
timedatectl set-timezone Europe/Moscow
#apt update
apt update
apt install mc ntp ntpd -y && systemctl enable ntpd
apt install borgbackup -y
echo "192.168.56.150    client" >> /etc/hosts
echo "192.168.56.160    backup" >> /etc/hosts
useradd -m borg
mkdir ~borg/.ssh
touch ~borg/.ssh/authorized_keys
chown -R borg:borg ~borg/.ssh
mkdir -p /opt/backup
chown borg:borg /opt/backup