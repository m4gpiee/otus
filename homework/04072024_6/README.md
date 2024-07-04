Задание 1: запустить NGINX сервер на нестандартном порту с включенным SELinux

Решение 1: 
С помощью audit2why проанализировать лог /var/log/audit/audit.log
В логе будет решение - с помощью команды setsebool -P nis_enabled 1 пофиксить проблему. 
Выполняем setsebool -P nis_enabled 1 и перезапускаем nginx - работает (см. скриншоты)

Решение 2: 
Добавить кастомный порт 4881 в список разрешенных http портов.

semanage port -a -t http_port_t -p tcp 4881
systemctl restart nginx.service 




Задание 2: обеспечить работоспособность приложения при включенном SELinux

Решение:
Выполним клонирование репозитория: git clone https://github.com/mbfx/otus-linux-adm.git

Попробуем внести изменения в dns зону:
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
[vagrant@client ~]$

Изменения не внесены. Проанализируем лог на клиентской и серверной машинах: cat /var/log/audit/audit.log | audit2why
На клиенте ошибок нет, но есть на сервере. Ошибка связана с контекстом безопасности - выбран тип etc_t вместо named_t.
Фикс:
chcon -R -t named_zone_t /etc/named
[root@ns01 vagrant]# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:named_zone_t:s0 .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:named_zone_t:s0 dynamic
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.50.168.192.rev
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.dns.lab.view1
-rw-rw----. root named system_u:object_r:named_zone_t:s0 named.newdns.lab

Пробуем внести изменения на клиенте и проверим:

[root@client vagrant]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
[root@client vagrant]# dig www.ddns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.16 <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 18054
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.ddns.lab.			IN	A

;; ANSWER SECTION:
www.ddns.lab.		60	IN	A	192.168.50.15

;; AUTHORITY SECTION:
ddns.lab.		3600	IN	NS	ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10

;; Query time: 11 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Чт июл 04 16:27:44 UTC 2024
;; MSG SIZE  rcvd: 96



Метод работает.

