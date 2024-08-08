В данной инструкции мы рассмотрим создание docker-compose файла для создания системы мониторинга на базе Prometheus + Grafana. 

Что мы получим:
Базу данных Prometheus и его встроенные графики на основе системных метрик prometheus node exporter;
Визуализация с помощью Grafana

Перед установкой:

Установить docker согласно офиц.инструкции https://docs.docker.com/engine/install/ubuntu/


Создать директорию:

```
mkdir -p /opt/prometheus_stack/{prometheus,grafana}
```

Создаем файл compose:

```
touch /opt/prometheus_stack/docker-compose.yml
```
Содержимое файла берем из приложенного docker-compose.yml

Создаем файл конфигурации prometheus:

```
touch prometheus/prometheus.yml
```
Содержимое файла берем из приложенного prometheus.yml и редактируем под себя, заменяя IP хоста с установленным node exporter

В директории /opt/prometheus_stack выполняем команду:

```
docker compose up -d 
```

Дожидаемся окончания и проверяем:
1. В браузере переходим http://yourip:9090/targets, убедимся, что наш endpoint имеет state UP
2. В браузере переходим http://yourip:3000 и видим стартовую страницу Grafana. Вводим дефолтные admin/admin, меняем пароль и попадаем в стоковую Grafana.
3. В Grafana переходим Home->connections-add data source и добавляем prometheus.
4. Если предыдущий шаг успешен - в Grafana переходим в Home->Dashboards->New->import.
5. В окне импорта вводим id дашборда 1860 и нажимаем load. 
6. Если всё успешно, то мы увидим страницу с настроенными графиками и показателями метрик.


Во вложенной директории pics можно посмотреть скриншоты

