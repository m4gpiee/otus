## Lesson36  VLAN'ы,LACP

<details>

### Задача

в Office1 в тестовой подсети появляется сервера с доп интерфесами и адресами
в internal сети testLAN: 
- testClient1 - 10.10.10.254
- testClient2 - 10.10.10.254
- testServer1- 10.10.10.1 
- testServer2- 10.10.10.1

Равести вланами:
testClient1 <-> testServer1
testClient2 <-> testServer2

Между centralRouter и inetRouter "пробросить" 2 линка (общая inernal сеть) и объединить их в бонд, проверить работу c отключением интерфейсов

Формат сдачи ДЗ - vagrant + ansible


### Решение

Итоговая топология

![Image 1](Lesson36_VLAN_LACP/Topology.jpg)

Разворачиваем настроенную топологию через ansible+vagrant+jinja2, проверяем настройки и доступность:

#### Client1
```
[vagrant@testClient1 ~]$ ip a | grep 10.10.10
    inet 10.10.10.254/24 brd 10.10.10.255 scope global noprefixroute eth1.1
```

```
[vagrant@testClient1 ~]$ ping 10.10.10.254
PING 10.10.10.254 (10.10.10.254) 56(84) bytes of data.
64 bytes from 10.10.10.254: icmp_seq=1 ttl=64 time=0.028 ms
64 bytes from 10.10.10.254: icmp_seq=2 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=3 ttl=64 time=0.025 ms
64 bytes from 10.10.10.254: icmp_seq=4 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=5 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=6 ttl=64 time=0.029 ms
64 bytes from 10.10.10.254: icmp_seq=7 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=8 ttl=64 time=0.027 ms
64 bytes from 10.10.10.254: icmp_seq=9 ttl=64 time=0.025 ms
64 bytes from 10.10.10.254: icmp_seq=10 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=11 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=12 ttl=64 time=0.025 ms
64 bytes from 10.10.10.254: icmp_seq=13 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=14 ttl=64 time=0.037 ms
64 bytes from 10.10.10.254: icmp_seq=15 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=16 ttl=64 time=0.026 ms
64 bytes from 10.10.10.254: icmp_seq=17 ttl=64 time=0.081 ms
^C
--- 10.10.10.254 ping statistics ---
17 packets transmitted, 17 received, 0% packet loss, time 16600ms
rtt min/avg/max/mdev = 0.025/0.030/0.081/0.013 ms
```

```
[vagrant@testClient1 ~]$ ping yandex.ru
PING yandex.ru (77.88.55.88) 56(84) bytes of data.
64 bytes from yandex.ru (77.88.55.88): icmp_seq=1 ttl=63 time=12.1 ms
64 bytes from yandex.ru (77.88.55.88): icmp_seq=2 ttl=63 time=11.7 ms
64 bytes from yandex.ru (77.88.55.88): icmp_seq=3 ttl=63 time=11.9 ms
^C
--- yandex.ru ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 11.677/11.887/12.102/0.173 ms
```


#### inetRouter

```
[vagrant@inetRouter ~]$ ping 192.168.255.2
PING 192.168.255.2 (192.168.255.2) 56(84) bytes of data.
64 bytes from 192.168.255.2: icmp_seq=1 ttl=64 time=0.694 ms
64 bytes from 192.168.255.2: icmp_seq=2 ttl=64 time=0.573 ms
64 bytes from 192.168.255.2: icmp_seq=3 ttl=64 time=0.601 ms

--- 192.168.255.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2026ms
rtt min/avg/max/mdev = 0.573/0.622/0.694/0.059 ms
```


####  centralRouter

```
[root@centralRouter ~]# ip a | grep bond
3: eth1: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc fq_codel master bond0 state UP group default qlen 1000
4: eth2: <BROADCAST,MULTICAST,SLAVE,UP,LOWER_UP> mtu 1500 qdisc fq_codel master bond0 state UP group default qlen 1000
7: bond0: <BROADCAST,MULTICAST,MASTER,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    inet 192.168.255.2/30 brd 192.168.255.3 scope global noprefixroute bond0
```

```
[root@centralRouter ~]# ping 192.168.255.1
PING 192.168.255.1 (192.168.255.1) 56(84) bytes of data.
64 bytes from 192.168.255.1: icmp_seq=1 ttl=64 time=0.917 ms
64 bytes from 192.168.255.1: icmp_seq=2 ttl=64 time=0.730 ms
^C
--- 192.168.255.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1060ms
rtt min/avg/max/mdev = 0.730/0.823/0.917/0.097 ms
```

```
[root@centralRouter ~]# ping yandex.ru
PING yandex.ru (5.255.255.70) 56(84) bytes of data.
64 bytes from yandex.ru (5.255.255.70): icmp_seq=1 ttl=63 time=8.62 ms
64 bytes from yandex.ru (5.255.255.70): icmp_seq=2 ttl=63 time=8.35 ms
^C
--- yandex.ru ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1025ms
rtt min/avg/max/mdev = 8.347/8.482/8.618/0.163 ms
```

</details>

