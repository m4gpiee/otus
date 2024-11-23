Перед выполнением задания необходимо правильно распределить подсети (nets.png)
Далее, нарисована сетевая диаграмма (network_dia.png)

Задание: 
-Соединить офисы в сеть согласно схемы и настроить роутинг
-Все сервера и роутеры должны ходить в инет черз inetRouter
-Все сервера должны видеть друг друга
-У всех новых серверов отключить дефолт на нат (eth0), который вагрант поднимает для связи


Решение(без Ansible)
Проверяем:

*** [vagrant@office2Server ~]$ *** traceroute yandex.ru
```
traceroute to yandex.ru (5.255.255.70), 30 hops max, 60 byte packets
 1  gateway (192.168.1.1)  0.805 ms  0.740 ms  0.551 ms
 2  192.168.253.1 (192.168.253.1)  2.148 ms  1.941 ms  1.892 ms
 3  192.168.255.1 (192.168.255.1)  1.576 ms  2.889 ms  2.729 ms
30  * * *
```

[vagrant@office2Server ~]$ ping yandex.ru

```
PING yandex.ru (77.88.55.60) 56(84) bytes of data.
64 bytes from yandex.ru (77.88.55.60): icmp_seq=1 ttl=57 time=13.9 ms
64 bytes from yandex.ru (77.88.55.60): icmp_seq=2 ttl=57 time=12.9 ms
--- yandex.ru ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 12.931/13.438/13.945/0.507 ms
[vagrant@office2Server ~]$ ping 192.168.2.2
PING 192.168.2.2 (192.168.2.2) 56(84) bytes of data.
64 bytes from 192.168.2.2: icmp_seq=1 ttl=61 time=2.33 ms
64 bytes from 192.168.2.2: icmp_seq=2 ttl=61 time=2.29 ms
64 bytes from 192.168.2.2: icmp_seq=3 ttl=61 time=2.06 ms
```
*** [vagrant@office2Router ~]$ *** traceroute yandex.ru

```
traceroute to yandex.ru (77.88.55.88), 30 hops max, 60 byte packets
 1  gateway (192.168.253.1)  0.688 ms  0.620 ms  0.298 ms
 2  192.168.255.1 (192.168.255.1)  0.805 ms  0.733 ms  0.681 ms
```

[vagrant@office2Router ~]$ ping 192.168.2.2
```
PING 192.168.2.2 (192.168.2.2) 56(84) bytes of data.
From 192.168.253.1 icmp_seq=1 Redirect Host(New nexthop: 192.168.254.2)
From 192.168.253.1: icmp_seq=1 Redirect Host(New nexthop: 192.168.254.2)
64 bytes from 192.168.2.2: icmp_seq=1 ttl=62 time=1.81 ms
From 192.168.253.1 icmp_seq=2 Redirect Host(New nexthop: 192.168.254.2)
From 192.168.253.1: icmp_seq=2 Redirect Host(New nexthop: 192.168.254.2)
```


*** [vagrant@office1Server ~]$ *** traceroute yandex.ru
```

traceroute to yandex.ru (5.255.255.70), 30 hops max, 60 byte packets
 1  gateway (192.168.2.1)  0.760 ms  0.361 ms  0.332 ms
 2  192.168.254.1 (192.168.254.1)  1.025 ms  1.103 ms  0.913 ms
 3  192.168.255.1 (192.168.255.1)  1.344 ms  1.623 ms  1.666 ms
[vagrant@office1Server ~]$ ping 192.168.1.2
PING 192.168.1.2 (192.168.1.2) 56(84) bytes of data.
64 bytes from 192.168.1.2: icmp_seq=1 ttl=61 time=2.22 ms
64 bytes from 192.168.1.2: icmp_seq=2 ttl=61 time=1.84 ms
64 bytes from 192.168.1.2: icmp_seq=3 ttl=61 time=1.79 ms
tes from 192.168.1.2: icmp_seq=19 ttl=61 time=2.11 ms
^C
--- 192.168.1.2 ping statistics ---
19 packets transmitted, 19 received, 0% packet loss, time 18038ms
rtt min/avg/max/mdev = 1.781/1.916/2.229/0.113 ms
```


*** [vagrant@office1Router ~]$ *** traceroute yandex.ru
```
traceroute to yandex.ru (5.255.255.70), 30 hops max, 60 byte packets
 1  gateway (192.168.254.1)  0.603 ms  0.472 ms  0.401 ms
 2  192.168.255.1 (192.168.255.1)  2.783 ms  4.805 ms  4.514 ms
30  * * *
[vagrant@office1Router ~]$ ping 192.168.1.2
PING 192.168.1.2 (192.168.1.2) 56(84) bytes of data.
From 192.168.254.1 icmp_seq=1 Redirect Host(New nexthop: 192.168.253.2)
From 192.168.254.1: icmp_seq=1 Redirect Host(New nexthop: 192.168.253.2)
```

[vagrant@centralServer ~]$ traceroute yandex.ru
```

traceroute to yandex.ru (77.88.55.60), 30 hops max, 60 byte packets
 1  gateway (192.168.0.1)  0.540 ms  0.476 ms  0.380 ms
 2  192.168.255.1 (192.168.255.1)  1.375 ms  1.500 ms  1.333 ms
30  * * *
[vagrant@centralServer ~]$ ping 192.168.1.2
PING 192.168.1.2 (192.168.1.2) 56(84) bytes of data.
64 bytes from 192.168.1.2: icmp_seq=1 ttl=62 time=1.75 ms
64 bytes from 192.168.1.2: icmp_seq=2 ttl=62 time=1.61 ms
```

[vagrant@centralServer ~]$ ping 192.168.2.2
```
PING 192.168.2.2 (192.168.2.2) 56(84) bytes of data.
64 bytes from 192.168.2.2: icmp_seq=1 ttl=62 time=1.78 ms
64 bytes from 192.168.2.2: icmp_seq=2 ttl=62 time=1.35 ms
```
