#!/bin/bash

apt update && apt install nginx -y
systemctl start nginx
systemctl enable nginx
apt install ntp ntpdate -y
service ntp stop
ntpdate -bs ru.pool.ntp.org
service ntp start
