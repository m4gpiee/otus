#!/bin/bash

# Действие 1: создать файл /etc/default/watchlog
cat <<EOF > /etc/default/watchlog
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF

# Действие 2: создать файл /var/log/watchlog.log и записать в него текущую дату и ALERT
/bin/echo `/bin/date "+%b %d %T"` ALERT >> /var/log/watchlog.log

# Действие 3: создать файл /opt/watchlog.sh с указанным содержимым
cat <<EOF > /opt/watchlog.sh
#!/bin/bash
WORD=\$1
LOG=\$2
DATE=\`date\`

if grep \$WORD \$LOG &> /dev/null
then
    logger "\$DATE: I found word, Master!"
else
    exit 0
fi
EOF

# Действие 4: сделать файл исполняемым
chmod +x /opt/watchlog.sh

# Действие 5: создать юнит для сервиса в /etc/systemd/system/watchlog.service
cat <<EOF > /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF

# Действие 6: создать юнит для таймера в /etc/systemd/system/watchlog.timer
cat <<EOF > /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 seconds

[Timer]
# Run every 30 seconds
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF

# Действие 7: установить spawn-fcgi и необходимые для него пакеты
apt install spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid -y

# Действие 8: создать файл с настройками для будущего сервиса /etc/spawn-fcgi/fcgi.conf
cat <<EOF > /etc/spawn-fcgi/fcgi.conf
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s \$SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
EOF

# Действие 9: создать unit файл /etc/systemd/system/spawn-fcgi.service
cat <<EOF > /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Действие 10: запустить сервис
systemctl start spawn-fcgi && systemctl status spawn-fcgi

# Действие 11: установить nginx
apt install nginx -y

# Действие 12: создать unit файл /etc/systemd/system/nginx@.service
cat <<EOF > /etc/systemd/system/nginx@.service
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Действие 13: создать два одинаковых файла /etc/nginx/nginx-first.conf и /etc/nginx/nginx-second.conf
cat <<EOF > /etc/nginx/nginx-first.conf
pid /run/nginx-first.pid;

http {
    server {
        listen 9001;
    }
    include /etc/nginx/sites-enabled/*;
}
EOF

cp /etc/nginx/nginx-first.conf /etc/nginx/nginx-second.conf

# Действие 14: запустить сервисы
systemctl start nginx@first
systemctl start nginx@second
