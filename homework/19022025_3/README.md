
## Lesson43 MYSQL BACKUP

<details>

### Задача

Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы:
| bookmaker |
| competition |
| market |
| odds |
| outcome

    Настроить GTID репликацию
    x
    варианты которые принимаются к сдаче

    рабочий вагрантафайл
    скрины или логи SHOW TABLES
    конфиги*
    пример в логе изменения строки и появления строки на реплике*


### Полезные ссылки
https://www.zyxware.com/articles/5589/solved-how-to-update-mysql-root-user-password
https://www.digitalocean.com/community/tutorials/how-to-reset-your-mysql-or-mariadb-root-password-on-ubuntu-20-04
Стенд


### Решение
Проводим настройки согласно методички, проверяем полученный результат.

На мастер хосте проверяем server_id, наличие импортированной бд, использование GTID.

![Image 1](Lesson43_mysql/master1.jpg)

Вносим изменения в бд.

![Image 1](Lesson43_mysql/master2.jpg)

На slave хосте проверяем server_id, использование GTID, наличие бд с изменениями и исключёнными таблицами:

![Image 1](Lesson43_mysql/slave1.jpg)

![Image 1](Lesson43_mysql/slave2.jpg)

</details>


