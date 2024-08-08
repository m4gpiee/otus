Порядок выполнения:
Создаем файл Dockerfile (во вложении)
Создаем директорию conf и два файла в ней:
1. default.conf - файл конфигурации nginx;
2. index.html - кастомная страница web сервера.



Запускаем создание docker образа:

```
 docker build .
[+] Building 5.5s (9/9) FINISHED                                                                                                                                                                    docker:default
 => [internal] load build definition from Dockerfile                                                                                                                                                          0.0s
 => => transferring dockerfile: 252B                                                                                                                                                                          0.0s
 => [internal] load metadata for docker.io/library/alpine:latest                                                                                                                                              1.7s
 => [internal] load .dockerignore                                                                                                                                                                             0.0s
 => => transferring context: 2B                                                                                                                                                                               0.0s
 => [1/4] FROM docker.io/library/alpine:latest@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5                                                                                        0.9s
 => => resolve docker.io/library/alpine:latest@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5                                                                                        0.0s
 => => sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5 1.85kB / 1.85kB                                                                                                                0.0s
 => => sha256:eddacbc7e24bf8799a4ed3cdcfa50d4b88a323695ad80f317b6629883b2c2a78 528B / 528B                                                                                                                    0.0s
 => => sha256:324bc02ae1231fd9255658c128086395d3fa0aedd5a41ab6b034fd649d1a9260 1.47kB / 1.47kB                                                                                                                0.0s
 => => sha256:c6a83fedfae6ed8a4f5f7cbb6a7b6f1c1ec3d86fea8cb9e5ba2e5e6673fde9f6 3.62MB / 3.62MB                                                                                                                0.8s
 => => extracting sha256:c6a83fedfae6ed8a4f5f7cbb6a7b6f1c1ec3d86fea8cb9e5ba2e5e6673fde9f6                                                                                                                     0.0s
 => [internal] load build context                                                                                                                                                                             0.0s
 => => transferring context: 323B                                                                                                                                                                             0.0s
 => [2/4] RUN apk update && apk upgrade && apk add nginx && apk add bash                                                                                                                                      2.7s
 => [3/4] COPY conf/default.conf /etc/nginx/http.d/                                                                                                                                                           0.0s
 => [4/4] COPY conf/index.html /var/www/default/html/                                                                                                                                                         0.1s
 => exporting to image                                                                                                                                                                                        0.0s 
 => => exporting layers                                                                                                                                                                                       0.0s 
 => => writing image sha256:014ec3fdfc176c77aac2a3a46c4cd18c1790c2faecb2dda89d124b280702370d                                                                                                                  0.0s 
```

Проверяем, что образ создался:

```
 docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
<none>       <none>    014ec3fdfc17   4 seconds ago   13.6MB
```

Запускаем контейнер, указывая порты как "локальный_порт:порт_в_докере":

```
 docker run -d -p 80:80 014ec3fdfc17
```

Проверяем, что контейнер запустился:

```
 docker ps
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS                               NAMES
38ece6ae257c   014ec3fdfc17   "nginx -g 'daemon of…"   4 seconds ago   Up 3 seconds   0.0.0.0:80->80/tcp, :::80->80/tcp   strange_elbakyan
```

Проверяем, что web сервер работает:

``` curl 127.0.0.1
Artem's custom index page
```

Выводы и ответы на вопросы:

1. Образ это как образ диска или VM, а контейнер - запущенная и кастомизированная VM из этого образа. 
2. Можно ли собрать в контейнере ядро? Можно, если не планируется его загружать в этом же контейнере.


