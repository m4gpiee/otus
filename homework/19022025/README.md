


SPLITDNS



### Задача

1. Взять стенд https://github.com/erlong15/vagrant-bind 
* добавить еще один сервер client2
* завести в зоне dns.lab имена:
* web1 - смотрит на клиент1
* web2  смотрит на клиент2
* завести еще одну зону newdns.lab
* завести в ней запись
* www - смотрит на обоих клиентов

2. настроить split-dns
клиент1 - видит обе зоны, но в зоне dns.lab только web1
клиент2 видит только dns.lab

* настроить все без выключения selinux


### Решение

Добавляем 2го клиента в Vagrant

```
  config.vm.define "client2" do |client2|
    client2.vm.network "private_network", ip: "192.168.50.16", virtualbox__intnet: "dns"
    client2.vm.hostname = "client2"
  end
```
Запускаем Vagrant+Ansible

Проверяем, что DNS поднялся:

```
[root@ns01 ~]# ss -tulpn | grep 53
udp    UNCONN     0      0      192.168.50.10:53                    *:*                   users:(("named",pid=2204,fd=512))
udp    UNCONN     0      0         [::1]:53                 [::]:*                   users:(("named",pid=2204,fd=513))
tcp    LISTEN     0      10     192.168.50.10:53                    *:*                   users:(("named",pid=2204,fd=21))
tcp    LISTEN     0      128    192.168.50.10:953                   *:*                   users:(("named",pid=2204,fd=23))
tcp    LISTEN     0      10        [::1]:53                 [::]:*                   users:(("named",pid=2204,fd=22))
```


#### Проверка добавления имён в зону dns.lab

```
[root@client ~]# dig @192.168.50.10 web1.dns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.13 <<>> @192.168.50.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 42560
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;web1.dns.lab.                  IN      A

;; ANSWER SECTION:
web1.dns.lab.           3600    IN      A       192.168.50.15

;; AUTHORITY SECTION:
dns.lab.                3600    IN      NS      ns02.dns.lab.
dns.lab.                3600    IN      NS      ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10
ns02.dns.lab.           3600    IN      A       192.168.50.11

;; Query time: 0 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Thu May 25 11:31:00 UTC 2023
;; MSG SIZE  rcvd: 127

```

![Image 1](Lesson35_DNS/dig1+2.jpg)


#### Настройка split-dns

Генерируем ключи для хостов

```
[root@ns01 ~]# tsig-keygen
key "tsig-key" {
        algorithm hmac-sha256;
        secret "hhRAf5ePYIwv99SmO1/sN6HibV9u1o+mjLI4kJc0XuY=";
};

[root@ns01 ~]# tsig-keygen

key "tsig-key" {
        algorithm hmac-sha256;
        secret "FGSuvjlp+h0ZX97/OpNFQVPk0eB61OqvQ8/X+3ZjokE=";
```

Настраиваем acl и view


```
[root@ns01 ~]# cat /etc/named.conf
options {

    // На каком порту и IP-адресе будет работать служба
        listen-on port 53 { 192.168.50.10; };
        listen-on-v6 port 53 { ::1; };

    // Указание каталогов с конфигурационными файлами
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";

    // Указание настроек DNS-сервера
    // Разрешаем серверу быть рекурсивным
        recursion yes;
    // Указываем сети, которым разрешено отправлять запросы серверу
        allow-query     { any; };
    // Каким сетям можно передавать настройки о зоне
    allow-transfer { any; };

    // dnssec
        dnssec-enable yes;
        dnssec-validation yes;

    // others
        bindkeys-file "/etc/named.iscdlv.key";
        managed-keys-directory "/var/named/dynamic";
        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

// RNDC Control for client
key "rndc-key" {
    algorithm hmac-md5;
    secret "GrtiE9kz16GK+OKKU/qJvQ==";
};
controls {
        inet 192.168.50.10 allow { 192.168.50.15; 192.168.50.16; } keys { "rndc-key"; };
};

key "client-key" {
    algorithm hmac-sha256;
    secret "hhRAf5ePYIwv99SmO1/sN6HibV9u1o+mjLI4kJc0XuY=";
};
key "client2-key" {
    algorithm hmac-sha256;
    secret "FGSuvjlp+h0ZX97/OpNFQVPk0eB61OqvQ8/X+3ZjokE=";
};

// ZONE TRANSFER WITH TSIG
include "/etc/named.zonetransfer.key";

server 192.168.50.11 {
    keys { "zonetransfer.key"; };
};
// Указание Access листов
acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };
// Настройка первого view
view "client" {
    // Кому из клиентов разрешено подключаться, нужно указать имя access-листа
    match-clients { client; };

    // Описание зоны dns.lab для client
    zone "dns.lab" {
        // Тип сервера — мастер
        type master;
        // Добавляем ссылку на файл зоны, который создали в прошлом пункте
        file "/etc/named/named.dns.lab.client";
        // Адрес хостов, которым будет отправлена информация об изменении зоны
        also-notify { 192.168.50.11 key client-key; };
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type master;
        file "/etc/named/named.newdns.lab";
        also-notify { 192.168.50.11 key client-key; };
    };
};

// Описание view для client2
view "client2" {
    match-clients { client2; };

    // dns.lab zone
    zone "dns.lab" {
        type master;
        file "/etc/named/named.dns.lab";
        also-notify { 192.168.50.11 key client2-key; };
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type master;
        file "/etc/named/named.dns.lab.rev";
        also-notify { 192.168.50.11 key client2-key; };
    };
};

// Зона any, указана в файле самой последней
view "default" {
    match-clients { any; };

    // root zone
    zone "." IN {
        type hint;
        file "named.ca";
    };

    // zones like localhost
    include "/etc/named.rfc1912.zones";
    // root DNSKEY
    include "/etc/named.root.key";

    // dns.lab zone
    zone "dns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.dns.lab";
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.dns.lab.rev";
    };

    // ddns.lab zone
    zone "ddns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        allow-update { key "zonetransfer.key"; };
        file "/etc/named/named.ddns.lab";
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.newdns.lab";
    };
};
```


#### Проверка на client и client2

![Image 1](Lesson35_DNS/splitDNSCheck.jpg)


#### Проверяем, что selinux включён

![Image 1](Lesson35_DNS/sestatus.jpg)




