# Репликация Postgres

* настроить hot_standby репликацию с использованием слотов
* настроить правильное резервное копирование

Для сдачи работы присылаем ссылку на репозиторий, в котором должны обязательно быть 

* Vagranfile (2 машины)
* плейбук Ansible
* конфигурационные файлы postgresql.conf, pg_hba.conf и recovery.conf,
* конфиг barman, либо скрипт резервного копирования.

Команда "vagrant up" должна поднимать машины с настроенной репликацией и резервным копированием. 
Рекомендуется в README.md файл вложить результаты (текст или скриншоты) проверки работы репликации и резервного копирования.

Пример плейбука:
```text
    name: Установка postgres11
    hosts: master, slave
    become: yes
    roles:
        postgres_install

    name: Настройка master
    hosts: master
    become: yes
    roles:
        master-setup

    name: Настройка slave
    hosts: slave
    become: yes
    roles:
        slave-setup

    name: Создание тестовой БД
    hosts: master
    become: yes
    roles:
        create_test_db

    name: Настройка barman
    hosts: barman
    become: yes
    roles:
        barman_install tags:
        barman
```

## Исполнение

### Поднятие виртуалок

```shell
cd ../../
cd ./040/vm/
vagrant destroy -f
vagrant up
python3 v2a.py -o ../ansible/inventories/hosts # Это уже как кредо
cd ../../
cd ./040/ansible/

```

### Репликация

* https://habr.com/ru/post/213409/
```text
Hot standby — позволяет slave нодам обслуживать READ запросы для балансировки нагрузки, в отличии от warm standby, при котором slave сервер не обслуживает запросов клиентов, а только постоянно подтягивает себе с мастера актуальную базу. 
```

#### Настройка мастера


<details><summary>см. pg_hba.conf</summary>

```text
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             all                                         peer
# IPv4 local connections:
host    all             all                 192.168.40.10/32        md5
host    replication     replicator          192.168.40.10/32        md5
host    replication     replicator          192.168.40.11/32        md5

```

</details>


<details><summary>см. postgresql.conf</summary>

```text
listen_addresses = '192.168.40.10,localhost'
max_connections = 100
shared_buffers = 128MB
dynamic_shared_memory_type = posix
wal_level = hot_standby # ВАЖНО В КОНТЕКСТЕ ЗАДАЧИ
# hot_standby = on # ВАЖНО В КОНТЕКСТЕ ЗАДАЧИ
synchronous_commit = local
max_wal_size = 1GB
min_wal_size = 80MB
max_wal_senders = 2
# wal_keep_segments = 10
max_replication_slots = 10
synchronous_standby_names = 'standby'
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%a.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 0
log_line_prefix = '%m [%p] '
log_timezone = 'UTC'
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'
default_text_search_config = 'pg_catalog.english'
archive_mode = on
# enables archiving; off, on, or always
# archive_command = 'barman-wal-archive backup master %p'

```

</details>

```shell
ansible-playbook playbooks/master.yml --tags deploy > ../files/001_playbooks-master.yml.txt
```


<details><summary>см. лог выполнения `playbooks/master.yml`</summary>

```text

PLAY [Playbook of PostgreSQL master] *******************************************

TASK [Gathering Facts] *********************************************************
ok: [master]

TASK [../roles/master : Install PostgreSQL repo] *******************************
changed: [master]

TASK [../roles/master : Install PostgreSQL] ************************************
changed: [master]

TASK [../roles/master : Uninstall PostgreSQL] **********************************
ok: [master]

TASK [../roles/master : Remove PostgreSQL data dir] ****************************
changed: [master]

TASK [../roles/master : Init PostgreSQL] ***************************************
changed: [master]

TASK [../roles/master : Collect-pg.conf-files] *********************************
changed: [master] => (item=pg_hba.conf)
changed: [master] => (item=postgresql.conf)

TASK [../roles/master : Force restart PostgreSQL] ******************************
changed: [master]

TASK [../roles/master : Create PostgreSQL slot] ********************************
changed: [master]

TASK [../roles/master : Create PostgreSQL replicator user] *********************
changed: [master]

RUNNING HANDLER [../roles/master : restart-postgresql] *************************
changed: [master]

PLAY RECAP *********************************************************************
master                     : ok=11   changed=9    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

#### Настройка реплики


<details><summary>см. postgresql.conf</summary>

```text
listen_addresses = '192.168.40.11,localhost'
max_connections = 100
shared_buffers = 128MB
dynamic_shared_memory_type = posix
synchronous_commit = local
max_wal_size = 1GB
min_wal_size = 80MB
archive_mode = on
max_wal_senders = 2
# wal_keep_segments = 10
max_replication_slots = 10
synchronous_standby_names = 'standby'
# wal_level = hot_standby # ВАЖНО В КОНТЕКСТЕ ЗАДАЧИ
hot_standby = on # ВАЖНО В КОНТЕКСТЕ ЗАДАЧИ
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%a.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 0
log_line_prefix = '%m [%p] '
log_timezone = 'UTC'
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'
default_text_search_config = 'pg_catalog.english'
# recovery.conf dedicated
# “standby_mode”: The former parameter “standby_mode” has been removed and has been replaced by the “standby.signal” and “recovery.signal”.
# standby_mode = on
primary_conninfo = 'host=192.168.40.10 port=5432 user=replicator password=replicator'
primary_slot_name = 'pg_slot_replication'
# “trigger_file”: The parameter “trigger_file” has been renamed to “promote_trigger_file“.
promote_trigger_file = '/tmp/trigger.192.168.40.10.5432'
```

</details>

```shell
ansible-playbook playbooks/replica.yml --tags deploy > ../files/002_playbooks-replica.yml.txt
```


<details><summary>см. лог выполнения `playbooks/replica.yml`</summary>

```text

PLAY [Playbook of PostgreSQL replica] ******************************************

TASK [Gathering Facts] *********************************************************
ok: [replica]

TASK [../roles/replica : Install EPEL Repo package from standart repo] *********
changed: [replica]

TASK [../roles/replica : Install PostgreSQL repo] ******************************
changed: [replica]

TASK [../roles/replica : Uninstall PostgreSQL] *********************************
ok: [replica]

TASK [../roles/replica : Remove PostgreSQL data dir] ***************************
ok: [replica]

TASK [../roles/replica : Install PostgreSQL] ***********************************
changed: [replica]

TASK [../roles/replica : Init PostgreSQL] **************************************
changed: [replica]

TASK [../roles/replica : Force clear PostgreSQL data dir] **********************
changed: [replica]

TASK [../roles/replica : Create PostgreSQL data] *******************************
changed: [replica]

TASK [../roles/replica : Install python-pip for pexpect promt answering] *******
changed: [replica]

TASK [../roles/replica : Pip install pexpect] **********************************
changed: [replica]

TASK [../roles/replica : Clear PostgreSQL data dir] ****************************
changed: [replica]

TASK [../roles/replica : Copy database from master to slave] *******************
changed: [replica]

TASK [../roles/replica : Collect pg.conf-files] ********************************
changed: [replica] => (item=postgresql.conf)
changed: [replica] => (item=recovery.signal)
changed: [replica] => (item=standby.signal)

RUNNING HANDLER [../roles/replica : restart-postgresql] ************************
changed: [replica]

PLAY RECAP *********************************************************************
replica                    : ok=15   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

#### Проверка работоспособности

##### Что есть на реплике до какой-либо CRUD-"активности" на мастере

```shell
ansible-playbook playbooks/replica_check_before.yml > ../files/003_playbooks-replica_check_before.yml.txt
```


<details><summary>см. лог выполнения `playbooks/replica_check_before.yml`</summary>

```text

PLAY [Playbook of check replica before master activity] ************************

TASK [Gathering Facts] *********************************************************
ok: [replica]

TASK [../roles/replica_check_before : PostgreSQL master checker] ***************
changed: [replica] => (item=SELECT datname AS database_name FROM pg_database;)
changed: [replica] => (item=SELECT schema_name FROM information_schema.schemata;)
changed: [replica] => (item=SELECT schemaname, tablename FROM pg_catalog.pg_tables;)
changed: [replica] => (item=SELECT name, setting, category, short_desc, context, pending_restart FROM pg_catalog.pg_settings ORDER BY category, name;)

TASK [../roles/replica_check_before : Store check to file] *********************
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:46.081799', 'stdout': ' database_name \n---------------\n postgres\n template1\n template0\n(3 строки)', 'cmd': 'sudo -iu postgres psql -c "SELECT datname AS database_name FROM pg_database;"', 'rc': 0, 'start': '2025-02-19 17:49:45.893179', 'stderr': '', 'delta': '0:00:00.188620', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT datname AS database_name FROM pg_database;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': [' database_name ', '---------------', ' postgres', ' template1', ' template0', '(3 строки)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT datname AS database_name FROM pg_database;', 'ansible_loop_var': 'item'})
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:46.720264', 'stdout': '    schema_name     \n--------------------\n pg_toast\n pg_catalog\n public\n information_schema\n(4 строки)', 'cmd': 'sudo -iu postgres psql -c "SELECT schema_name FROM information_schema.schemata;"', 'rc': 0, 'start': '2025-02-19 17:49:46.597634', 'stderr': '', 'delta': '0:00:00.122630', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT schema_name FROM information_schema.schemata;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['    schema_name     ', '--------------------', ' pg_toast', ' pg_catalog', ' public', ' information_schema', '(4 строки)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT schema_name FROM information_schema.schemata;', 'ansible_loop_var': 'item'})
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:47.363317', 'stdout': '     schemaname     |        tablename        \n--------------------+-------------------------\n pg_catalog         | pg_statistic\n pg_catalog         | pg_type\n pg_catalog         | pg_foreign_table\n pg_catalog         | pg_authid\n pg_catalog         | pg_statistic_ext_data\n pg_catalog         | pg_largeobject\n pg_catalog         | pg_user_mapping\n pg_catalog         | pg_subscription\n pg_catalog         | pg_attribute\n pg_catalog         | pg_proc\n pg_catalog         | pg_class\n pg_catalog         | pg_attrdef\n pg_catalog         | pg_constraint\n pg_catalog         | pg_inherits\n pg_catalog         | pg_index\n pg_catalog         | pg_operator\n pg_catalog         | pg_opfamily\n pg_catalog         | pg_opclass\n pg_catalog         | pg_am\n pg_catalog         | pg_amop\n pg_catalog         | pg_amproc\n pg_catalog         | pg_language\n pg_catalog         | pg_largeobject_metadata\n pg_catalog         | pg_aggregate\n pg_catalog         | pg_statistic_ext\n pg_catalog         | pg_rewrite\n pg_catalog         | pg_trigger\n pg_catalog         | pg_event_trigger\n pg_catalog         | pg_description\n pg_catalog         | pg_cast\n pg_catalog         | pg_enum\n pg_catalog         | pg_namespace\n pg_catalog         | pg_conversion\n pg_catalog         | pg_depend\n pg_catalog         | pg_database\n pg_catalog         | pg_db_role_setting\n pg_catalog         | pg_tablespace\n pg_catalog         | pg_auth_members\n pg_catalog         | pg_shdepend\n pg_catalog         | pg_shdescription\n pg_catalog         | pg_ts_config\n pg_catalog         | pg_ts_config_map\n pg_catalog         | pg_ts_dict\n pg_catalog         | pg_ts_parser\n pg_catalog         | pg_ts_template\n pg_catalog         | pg_extension\n pg_catalog         | pg_foreign_data_wrapper\n pg_catalog         | pg_foreign_server\n pg_catalog         | pg_policy\n pg_catalog         | pg_replication_origin\n pg_catalog         | pg_default_acl\n pg_catalog         | pg_init_privs\n pg_catalog         | pg_seclabel\n pg_catalog         | pg_shseclabel\n pg_catalog         | pg_collation\n pg_catalog         | pg_partitioned_table\n pg_catalog         | pg_range\n pg_catalog         | pg_transform\n pg_catalog         | pg_sequence\n pg_catalog         | pg_publication\n pg_catalog         | pg_publication_rel\n pg_catalog         | pg_subscription_rel\n information_schema | sql_implementation_info\n information_schema | sql_parts\n information_schema | sql_sizing\n information_schema | sql_features\n(66 строк)', 'cmd': 'sudo -iu postgres psql -c "SELECT schemaname, tablename FROM pg_catalog.pg_tables;"', 'rc': 0, 'start': '2025-02-19 17:49:47.236057', 'stderr': '', 'delta': '0:00:00.127260', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT schemaname, tablename FROM pg_catalog.pg_tables;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['     schemaname     |        tablename        ', '--------------------+-------------------------', ' pg_catalog         | pg_statistic', ' pg_catalog         | pg_type', ' pg_catalog         | pg_foreign_table', ' pg_catalog         | pg_authid', ' pg_catalog         | pg_statistic_ext_data', ' pg_catalog         | pg_largeobject', ' pg_catalog         | pg_user_mapping', ' pg_catalog         | pg_subscription', ' pg_catalog         | pg_attribute', ' pg_catalog         | pg_proc', ' pg_catalog         | pg_class', ' pg_catalog         | pg_attrdef', ' pg_catalog         | pg_constraint', ' pg_catalog         | pg_inherits', ' pg_catalog         | pg_index', ' pg_catalog         | pg_operator', ' pg_catalog         | pg_opfamily', ' pg_catalog         | pg_opclass', ' pg_catalog         | pg_am', ' pg_catalog         | pg_amop', ' pg_catalog         | pg_amproc', ' pg_catalog         | pg_language', ' pg_catalog         | pg_largeobject_metadata', ' pg_catalog         | pg_aggregate', ' pg_catalog         | pg_statistic_ext', ' pg_catalog         | pg_rewrite', ' pg_catalog         | pg_trigger', ' pg_catalog         | pg_event_trigger', ' pg_catalog         | pg_description', ' pg_catalog         | pg_cast', ' pg_catalog         | pg_enum', ' pg_catalog         | pg_namespace', ' pg_catalog         | pg_conversion', ' pg_catalog         | pg_depend', ' pg_catalog         | pg_database', ' pg_catalog         | pg_db_role_setting', ' pg_catalog         | pg_tablespace', ' pg_catalog         | pg_auth_members', ' pg_catalog         | pg_shdepend', ' pg_catalog         | pg_shdescription', ' pg_catalog         | pg_ts_config', ' pg_catalog         | pg_ts_config_map', ' pg_catalog         | pg_ts_dict', ' pg_catalog         | pg_ts_parser', ' pg_catalog         | pg_ts_template', ' pg_catalog         | pg_extension', ' pg_catalog         | pg_foreign_data_wrapper', ' pg_catalog         | pg_foreign_server', ' pg_catalog         | pg_policy', ' pg_catalog         | pg_replication_origin', ' pg_catalog         | pg_default_acl', ' pg_catalog         | pg_init_privs', ' pg_catalog         | pg_seclabel', ' pg_catalog         | pg_shseclabel', ' pg_catalog         | pg_collation', ' pg_catalog         | pg_partitioned_table', ' pg_catalog         | pg_range', ' pg_catalog         | pg_transform', ' pg_catalog         | pg_sequence', ' pg_catalog         | pg_publication', ' pg_catalog         | pg_publication_rel', ' pg_catalog         | pg_subscription_rel', ' information_schema | sql_implementation_info', ' information_schema | sql_parts', ' information_schema | sql_sizing', ' information_schema | sql_features', '(66 строк)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT schemaname, tablename FROM pg_catalog.pg_tables;', 'ansible_loop_var': 'item'})
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:48.017051', 'stdout': '                  name                  |                             setting                              |                             category                              |                                                               short_desc                                                                |      context      | pending_restart \n----------------------------------------+------------------------------------------------------------------+-------------------------------------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+-------------------+-----------------\n autovacuum                             | on                                                               | Autovacuum                                                        | Starts the autovacuum subprocess.                                                                                                       | sighup            | f\n autovacuum_analyze_scale_factor        | 0.1                                                              | Autovacuum                                                        | Number of tuple inserts, updates, or deletes prior to analyze as a fraction of reltuples.                                               | sighup            | f\n autovacuum_analyze_threshold           | 50                                                               | Autovacuum                                                        | Minimum number of tuple inserts, updates, or deletes prior to analyze.                                                                  | sighup            | f\n autovacuum_freeze_max_age              | 200000000                                                        | Autovacuum                                                        | Age at which to autovacuum a table to prevent transaction ID wraparound.                                                                | postmaster        | f\n autovacuum_max_workers                 | 3                                                                | Autovacuum                                                        | Sets the maximum number of simultaneously running autovacuum worker processes.                                                          | postmaster        | f\n autovacuum_multixact_freeze_max_age    | 400000000                                                        | Autovacuum                                                        | Multixact age at which to autovacuum a table to prevent multixact wraparound.                                                           | postmaster        | f\n autovacuum_naptime                     | 60                                                               | Autovacuum                                                        | Time to sleep between autovacuum runs.                                                                                                  | sighup            | f\n autovacuum_vacuum_cost_delay           | 2                                                                | Autovacuum                                                        | Vacuum cost delay in milliseconds, for autovacuum.                                                                                      | sighup            | f\n autovacuum_vacuum_cost_limit           | -1                                                               | Autovacuum                                                        | Vacuum cost amount available before napping, for autovacuum.                                                                            | sighup            | f\n autovacuum_vacuum_insert_scale_factor  | 0.2                                                              | Autovacuum                                                        | Number of tuple inserts prior to vacuum as a fraction of reltuples.                                                                     | sighup            | f\n autovacuum_vacuum_insert_threshold     | 1000                                                             | Autovacuum                                                        | Minimum number of tuple inserts prior to vacuum, or -1 to disable insert vacuums.                                                       | sighup            | f\n autovacuum_vacuum_scale_factor         | 0.2                                                              | Autovacuum                                                        | Number of tuple updates or deletes prior to vacuum as a fraction of reltuples.                                                          | sighup            | f\n autovacuum_vacuum_threshold            | 50                                                               | Autovacuum                                                        | Minimum number of tuple updates or deletes prior to vacuum.                                                                             | sighup            | f\n client_encoding                        | UTF8                                                             | Client Connection Defaults / Locale and Formatting                | Sets the client\'s character set encoding.                                                                                               | user              | f\n DateStyle                              | ISO, MDY                                                         | Client Connection Defaults / Locale and Formatting                | Sets the display format for date and time values.                                                                                       | user              | f\n default_text_search_config             | pg_catalog.english                                               | Client Connection Defaults / Locale and Formatting                | Sets default text search configuration.                                                                                                 | user              | f\n extra_float_digits                     | 1                                                                | Client Connection Defaults / Locale and Formatting                | Sets the number of digits displayed for floating-point values.                                                                          | user              | f\n IntervalStyle                          | postgres                                                         | Client Connection Defaults / Locale and Formatting                | Sets the display format for interval values.                                                                                            | user              | f\n lc_collate                             | en_US.UTF-8                                                      | Client Connection Defaults / Locale and Formatting                | Shows the collation order locale.                                                                                                       | internal          | f\n lc_ctype                               | en_US.UTF-8                                                      | Client Connection Defaults / Locale and Formatting                | Shows the character classification and case conversion locale.                                                                          | internal          | f\n lc_messages                            | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the language in which messages are displayed.                                                                                      | superuser         | f\n lc_monetary                            | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the locale for formatting monetary amounts.                                                                                        | user              | f\n lc_numeric                             | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the locale for formatting numbers.                                                                                                 | user              | f\n lc_time                                | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the locale for formatting date and time values.                                                                                    | user              | f\n server_encoding                        | UTF8                                                             | Client Connection Defaults / Locale and Formatting                | Sets the server (database) character set encoding.                                                                                      | internal          | f\n TimeZone                               | UTC                                                              | Client Connection Defaults / Locale and Formatting                | Sets the time zone for displaying and interpreting time stamps.                                                                         | user              | f\n timezone_abbreviations                 | Default                                                          | Client Connection Defaults / Locale and Formatting                | Selects a file of time zone abbreviations.                                                                                              | user              | f\n dynamic_library_path                   | $libdir                                                          | Client Connection Defaults / Other Defaults                       | Sets the path for dynamically loadable modules.                                                                                         | superuser         | f\n gin_fuzzy_search_limit                 | 0                                                                | Client Connection Defaults / Other Defaults                       | Sets the maximum allowed result for exact search by GIN.                                                                                | user              | f\n tcp_keepalives_count                   | 0                                                                | Client Connection Defaults / Other Defaults                       | Maximum number of TCP keepalive retransmits.                                                                                            | user              | f\n tcp_keepalives_idle                    | 0                                                                | Client Connection Defaults / Other Defaults                       | Time between issuing TCP keepalives.                                                                                                    | user              | f\n tcp_keepalives_interval                | 0                                                                | Client Connection Defaults / Other Defaults                       | Time between TCP keepalive retransmits.                                                                                                 | user              | f\n tcp_user_timeout                       | 0                                                                | Client Connection Defaults / Other Defaults                       | TCP user timeout.                                                                                                                       | user              | f\n jit_provider                           | llvmjit                                                          | Client Connection Defaults / Shared Library Preloading            | JIT provider to use.                                                                                                                    | postmaster        | f\n local_preload_libraries                |                                                                  | Client Connection Defaults / Shared Library Preloading            | Lists unprivileged shared libraries to preload into each backend.                                                                       | user              | f\n session_preload_libraries              |                                                                  | Client Connection Defaults / Shared Library Preloading            | Lists shared libraries to preload into each backend.                                                                                    | superuser         | f\n shared_preload_libraries               |                                                                  | Client Connection Defaults / Shared Library Preloading            | Lists shared libraries to preload into server.                                                                                          | postmaster        | f\n bytea_output                           | hex                                                              | Client Connection Defaults / Statement Behavior                   | Sets the output format for bytea.                                                                                                       | user              | f\n check_function_bodies                  | on                                                               | Client Connection Defaults / Statement Behavior                   | Check function bodies during CREATE FUNCTION.                                                                                           | user              | f\n client_min_messages                    | notice                                                           | Client Connection Defaults / Statement Behavior                   | Sets the message levels that are sent to the client.                                                                                    | user              | f\n default_table_access_method            | heap                                                             | Client Connection Defaults / Statement Behavior                   | Sets the default table access method for new tables.                                                                                    | user              | f\n default_tablespace                     |                                                                  | Client Connection Defaults / Statement Behavior                   | Sets the default tablespace to create tables and indexes in.                                                                            | user              | f\n default_transaction_deferrable         | off                                                              | Client Connection Defaults / Statement Behavior                   | Sets the default deferrable status of new transactions.                                                                                 | user              | f\n default_transaction_isolation          | read committed                                                   | Client Connection Defaults / Statement Behavior                   | Sets the transaction isolation level of each new transaction.                                                                           | user              | f\n default_transaction_read_only          | off                                                              | Client Connection Defaults / Statement Behavior                   | Sets the default read-only status of new transactions.                                                                                  | user              | f\n gin_pending_list_limit                 | 4096                                                             | Client Connection Defaults / Statement Behavior                   | Sets the maximum size of the pending list for GIN index.                                                                                | user              | f\n idle_in_transaction_session_timeout    | 0                                                                | Client Connection Defaults / Statement Behavior                   | Sets the maximum allowed duration of any idling transaction.                                                                            | user              | f\n lock_timeout                           | 0                                                                | Client Connection Defaults / Statement Behavior                   | Sets the maximum allowed duration of any wait for a lock.                                                                               | user              | f\n row_security                           | on                                                               | Client Connection Defaults / Statement Behavior                   | Enable row security.                                                                                                                    | user              | f\n search_path                            | "$user", public                                                  | Client Connection Defaults / Statement Behavior                   | Sets the schema search order for names that are not schema-qualified.                                                                   | user              | f\n session_replication_role               | origin                                                           | Client Connection Defaults / Statement Behavior                   | Sets the session\'s behavior for triggers and rewrite rules.                                                                             | superuser         | f\n statement_timeout                      | 0                                                                | Client Connection Defaults / Statement Behavior                   | Sets the maximum allowed duration of any statement.                                                                                     | user              | f\n temp_tablespaces                       |                                                                  | Client Connection Defaults / Statement Behavior                   | Sets the tablespace(s) to use for temporary tables and sort files.                                                                      | user              | f\n transaction_deferrable                 | off                                                              | Client Connection Defaults / Statement Behavior                   | Whether to defer a read-only serializable transaction until it can be executed with no possible serialization failures.                 | user              | f\n transaction_isolation                  | read committed                                                   | Client Connection Defaults / Statement Behavior                   | Sets the current transaction\'s isolation level.                                                                                         | user              | f\n transaction_read_only                  | on                                                               | Client Connection Defaults / Statement Behavior                   | Sets the current transaction\'s read-only status.                                                                                        | user              | f\n vacuum_cleanup_index_scale_factor      | 0.1                                                              | Client Connection Defaults / Statement Behavior                   | Number of tuple inserts prior to index cleanup as a fraction of reltuples.                                                              | user              | f\n vacuum_freeze_min_age                  | 50000000                                                         | Client Connection Defaults / Statement Behavior                   | Minimum age at which VACUUM should freeze a table row.                                                                                  | user              | f\n vacuum_freeze_table_age                | 150000000                                                        | Client Connection Defaults / Statement Behavior                   | Age at which VACUUM should scan whole table to freeze tuples.                                                                           | user              | f\n vacuum_multixact_freeze_min_age        | 5000000                                                          | Client Connection Defaults / Statement Behavior                   | Minimum age at which VACUUM should freeze a MultiXactId in a table row.                                                                 | user              | f\n vacuum_multixact_freeze_table_age      | 150000000                                                        | Client Connection Defaults / Statement Behavior                   | Multixact age at which VACUUM should scan whole table to freeze tuples.                                                                 | user              | f\n xmlbinary                              | base64                                                           | Client Connection Defaults / Statement Behavior                   | Sets how binary values are to be encoded in XML.                                                                                        | user              | f\n xmloption                              | content                                                          | Client Connection Defaults / Statement Behavior                   | Sets whether XML data in implicit parsing and serialization operations is to be considered as documents or content fragments.           | user              | f\n authentication_timeout                 | 60                                                               | Connections and Authentication / Authentication                   | Sets the maximum allowed time to complete client authentication.                                                                        | sighup            | f\n db_user_namespace                      | off                                                              | Connections and Authentication / Authentication                   | Enables per-database user names.                                                                                                        | sighup            | f\n krb_caseins_users                      | off                                                              | Connections and Authentication / Authentication                   | Sets whether Kerberos and GSSAPI user names should be treated as case-insensitive.                                                      | sighup            | f\n krb_server_keyfile                     | FILE:/etc/sysconfig/pgsql/krb5.keytab                            | Connections and Authentication / Authentication                   | Sets the location of the Kerberos server key file.                                                                                      | sighup            | f\n password_encryption                    | md5                                                              | Connections and Authentication / Authentication                   | Chooses the algorithm for encrypting passwords.                                                                                         | user              | f\n bonjour                                | off                                                              | Connections and Authentication / Connection Settings              | Enables advertising the server via Bonjour.                                                                                             | postmaster        | f\n bonjour_name                           |                                                                  | Connections and Authentication / Connection Settings              | Sets the Bonjour service name.                                                                                                          | postmaster        | f\n listen_addresses                       | 192.168.40.11,localhost                                          | Connections and Authentication / Connection Settings              | Sets the host name or IP address(es) to listen to.                                                                                      | postmaster        | f\n max_connections                        | 100                                                              | Connections and Authentication / Connection Settings              | Sets the maximum number of concurrent connections.                                                                                      | postmaster        | f\n port                                   | 5432                                                             | Connections and Authentication / Connection Settings              | Sets the TCP port the server listens on.                                                                                                | postmaster        | f\n superuser_reserved_connections         | 3                                                                | Connections and Authentication / Connection Settings              | Sets the number of connection slots reserved for superusers.                                                                            | postmaster        | f\n unix_socket_directories                | /var/run/postgresql, /tmp                                        | Connections and Authentication / Connection Settings              | Sets the directories where Unix-domain sockets will be created.                                                                         | postmaster        | f\n unix_socket_group                      |                                                                  | Connections and Authentication / Connection Settings              | Sets the owning group of the Unix-domain socket.                                                                                        | postmaster        | f\n unix_socket_permissions                | 0777                                                             | Connections and Authentication / Connection Settings              | Sets the access permissions of the Unix-domain socket.                                                                                  | postmaster        | f\n ssl                                    | off                                                              | Connections and Authentication / SSL                              | Enables SSL connections.                                                                                                                | sighup            | f\n ssl_ca_file                            |                                                                  | Connections and Authentication / SSL                              | Location of the SSL certificate authority file.                                                                                         | sighup            | f\n ssl_cert_file                          | server.crt                                                       | Connections and Authentication / SSL                              | Location of the SSL server certificate file.                                                                                            | sighup            | f\n ssl_ciphers                            | HIGH:MEDIUM:+3DES:!aNULL                                         | Connections and Authentication / SSL                              | Sets the list of allowed SSL ciphers.                                                                                                   | sighup            | f\n ssl_crl_file                           |                                                                  | Connections and Authentication / SSL                              | Location of the SSL certificate revocation list file.                                                                                   | sighup            | f\n ssl_dh_params_file                     |                                                                  | Connections and Authentication / SSL                              | Location of the SSL DH parameters file.                                                                                                 | sighup            | f\n ssl_ecdh_curve                         | prime256v1                                                       | Connections and Authentication / SSL                              | Sets the curve to use for ECDH.                                                                                                         | sighup            | f\n ssl_key_file                           | server.key                                                       | Connections and Authentication / SSL                              | Location of the SSL server private key file.                                                                                            | sighup            | f\n ssl_max_protocol_version               |                                                                  | Connections and Authentication / SSL                              | Sets the maximum SSL/TLS protocol version to use.                                                                                       | sighup            | f\n ssl_min_protocol_version               | TLSv1.2                                                          | Connections and Authentication / SSL                              | Sets the minimum SSL/TLS protocol version to use.                                                                                       | sighup            | f\n ssl_passphrase_command                 |                                                                  | Connections and Authentication / SSL                              | Command to obtain passphrases for SSL.                                                                                                  | sighup            | f\n ssl_passphrase_command_supports_reload | off                                                              | Connections and Authentication / SSL                              | Also use ssl_passphrase_command during server reload.                                                                                   | sighup            | f\n ssl_prefer_server_ciphers              | on                                                               | Connections and Authentication / SSL                              | Give priority to server ciphersuite order.                                                                                              | sighup            | f\n allow_system_table_mods                | off                                                              | Developer Options                                                 | Allows modifications of the structure of system tables.                                                                                 | superuser         | f\n backtrace_functions                    |                                                                  | Developer Options                                                 | Log backtrace for errors in these functions.                                                                                            | superuser         | f\n ignore_checksum_failure                | off                                                              | Developer Options                                                 | Continues processing after a checksum failure.                                                                                          | superuser         | f\n ignore_invalid_pages                   | off                                                              | Developer Options                                                 | Continues recovery after an invalid pages failure.                                                                                      | postmaster        | f\n ignore_system_indexes                  | off                                                              | Developer Options                                                 | Disables reading from system indexes.                                                                                                   | backend           | f\n jit_debugging_support                  | off                                                              | Developer Options                                                 | Register JIT compiled function with debugger.                                                                                           | superuser-backend | f\n jit_dump_bitcode                       | off                                                              | Developer Options                                                 | Write out LLVM bitcode to facilitate JIT debugging.                                                                                     | superuser         | f\n jit_expressions                        | on                                                               | Developer Options                                                 | Allow JIT compilation of expressions.                                                                                                   | user              | f\n jit_profiling_support                  | off                                                              | Developer Options                                                 | Register JIT compiled function with perf profiler.                                                                                      | superuser-backend | f\n jit_tuple_deforming                    | on                                                               | Developer Options                                                 | Allow JIT compilation of tuple deforming.                                                                                               | user              | f\n post_auth_delay                        | 0                                                                | Developer Options                                                 | Waits N seconds on connection startup after authentication.                                                                             | backend           | f\n pre_auth_delay                         | 0                                                                | Developer Options                                                 | Waits N seconds on connection startup before authentication.                                                                            | sighup            | f\n trace_notify                           | off                                                              | Developer Options                                                 | Generates debugging output for LISTEN and NOTIFY.                                                                                       | user              | f\n trace_recovery_messages                | log                                                              | Developer Options                                                 | Enables logging of recovery-related debugging information.                                                                              | sighup            | f\n trace_sort                             | off                                                              | Developer Options                                                 | Emit information about resource usage in sorting.                                                                                       | user              | f\n wal_consistency_checking               |                                                                  | Developer Options                                                 | Sets the WAL resource managers for which WAL consistency checks are done.                                                               | superuser         | f\n zero_damaged_pages                     | off                                                              | Developer Options                                                 | Continues processing past damaged page headers.                                                                                         | superuser         | f\n data_sync_retry                        | off                                                              | Error Handling                                                    | Whether to continue running after a failure to sync data files.                                                                         | postmaster        | f\n exit_on_error                          | off                                                              | Error Handling                                                    | Terminate session on any error.                                                                                                         | user              | f\n restart_after_crash                    | on                                                               | Error Handling                                                    | Reinitialize server after backend crash.                                                                                                | sighup            | f\n config_file                            | /var/lib/pgsql/13/data/postgresql.conf                           | File Locations                                                    | Sets the server\'s main configuration file.                                                                                              | postmaster        | f\n data_directory                         | /var/lib/pgsql/13/data                                           | File Locations                                                    | Sets the server\'s data directory.                                                                                                       | postmaster        | f\n external_pid_file                      |                                                                  | File Locations                                                    | Writes the postmaster PID to the specified file.                                                                                        | postmaster        | f\n hba_file                               | /var/lib/pgsql/13/data/pg_hba.conf                               | File Locations                                                    | Sets the server\'s "hba" configuration file.                                                                                             | postmaster        | f\n ident_file                             | /var/lib/pgsql/13/data/pg_ident.conf                             | File Locations                                                    | Sets the server\'s "ident" configuration file.                                                                                           | postmaster        | f\n deadlock_timeout                       | 1000                                                             | Lock Management                                                   | Sets the time to wait on a lock before checking for deadlock.                                                                           | superuser         | f\n max_locks_per_transaction              | 64                                                               | Lock Management                                                   | Sets the maximum number of locks per transaction.                                                                                       | postmaster        | f\n max_pred_locks_per_page                | 2                                                                | Lock Management                                                   | Sets the maximum number of predicate-locked tuples per page.                                                                            | sighup            | f\n max_pred_locks_per_relation            | -2                                                               | Lock Management                                                   | Sets the maximum number of predicate-locked pages and tuples per relation.                                                              | sighup            | f\n max_pred_locks_per_transaction         | 64                                                               | Lock Management                                                   | Sets the maximum number of predicate locks per transaction.                                                                             | postmaster        | f\n block_size                             | 8192                                                             | Preset Options                                                    | Shows the size of a disk block.                                                                                                         | internal          | f\n data_checksums                         | off                                                              | Preset Options                                                    | Shows whether data checksums are turned on for this cluster.                                                                            | internal          | f\n data_directory_mode                    | 0700                                                             | Preset Options                                                    | Mode of the data directory.                                                                                                             | internal          | f\n debug_assertions                       | off                                                              | Preset Options                                                    | Shows whether the running server has assertion checks enabled.                                                                          | internal          | f\n integer_datetimes                      | on                                                               | Preset Options                                                    | Datetimes are integer based.                                                                                                            | internal          | f\n max_function_args                      | 100                                                              | Preset Options                                                    | Shows the maximum number of function arguments.                                                                                         | internal          | f\n max_identifier_length                  | 63                                                               | Preset Options                                                    | Shows the maximum identifier length.                                                                                                    | internal          | f\n max_index_keys                         | 32                                                               | Preset Options                                                    | Shows the maximum number of index keys.                                                                                                 | internal          | f\n segment_size                           | 131072                                                           | Preset Options                                                    | Shows the number of pages per disk file.                                                                                                | internal          | f\n server_version                         | 13.5                                                             | Preset Options                                                    | Shows the server version.                                                                                                               | internal          | f\n server_version_num                     | 130005                                                           | Preset Options                                                    | Shows the server version as an integer.                                                                                                 | internal          | f\n ssl_library                            | OpenSSL                                                          | Preset Options                                                    | Name of the SSL library.                                                                                                                | internal          | f\n wal_block_size                         | 8192                                                             | Preset Options                                                    | Shows the block size in the write ahead log.                                                                                            | internal          | f\n wal_segment_size                       | 16777216                                                         | Preset Options                                                    | Shows the size of write ahead log segments.                                                                                             | internal          | f\n cluster_name                           |                                                                  | Process Title                                                     | Sets the name of the cluster, which is included in the process title.                                                                   | postmaster        | f\n update_process_title                   | on                                                               | Process Title                                                     | Updates the process title to show the active SQL command.                                                                               | superuser         | f\n geqo                                   | on                                                               | Query Tuning / Genetic Query Optimizer                            | Enables genetic query optimization.                                                                                                     | user              | f\n geqo_effort                            | 5                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: effort is used to set the default for other GEQO parameters.                                                                      | user              | f\n geqo_generations                       | 0                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: number of iterations of the algorithm.                                                                                            | user              | f\n geqo_pool_size                         | 0                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: number of individuals in the population.                                                                                          | user              | f\n geqo_seed                              | 0                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: seed for random path selection.                                                                                                   | user              | f\n geqo_selection_bias                    | 2                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: selective pressure within the population.                                                                                         | user              | f\n geqo_threshold                         | 12                                                               | Query Tuning / Genetic Query Optimizer                            | Sets the threshold of FROM items beyond which GEQO is used.                                                                             | user              | f\n constraint_exclusion                   | partition                                                        | Query Tuning / Other Planner Options                              | Enables the planner to use constraints to optimize queries.                                                                             | user              | f\n cursor_tuple_fraction                  | 0.1                                                              | Query Tuning / Other Planner Options                              | Sets the planner\'s estimate of the fraction of a cursor\'s rows that will be retrieved.                                                  | user              | f\n default_statistics_target              | 100                                                              | Query Tuning / Other Planner Options                              | Sets the default statistics target.                                                                                                     | user              | f\n force_parallel_mode                    | off                                                              | Query Tuning / Other Planner Options                              | Forces use of parallel query facilities.                                                                                                | user              | f\n from_collapse_limit                    | 8                                                                | Query Tuning / Other Planner Options                              | Sets the FROM-list size beyond which subqueries are not collapsed.                                                                      | user              | f\n jit                                    | on                                                               | Query Tuning / Other Planner Options                              | Allow JIT compilation.                                                                                                                  | user              | f\n join_collapse_limit                    | 8                                                                | Query Tuning / Other Planner Options                              | Sets the FROM-list size beyond which JOIN constructs are not flattened.                                                                 | user              | f\n plan_cache_mode                        | auto                                                             | Query Tuning / Other Planner Options                              | Controls the planner\'s selection of custom or generic plan.                                                                             | user              | f\n cpu_index_tuple_cost                   | 0.005                                                            | Query Tuning / Planner Cost Constants                             | Sets the planner\'s estimate of the cost of processing each index entry during an index scan.                                            | user              | f\n cpu_operator_cost                      | 0.0025                                                           | Query Tuning / Planner Cost Constants                             | Sets the planner\'s estimate of the cost of processing each operator or function call.                                                   | user              | f\n cpu_tuple_cost                         | 0.01                                                             | Query Tuning / Planner Cost Constants                             | Sets the planner\'s estimate of the cost of processing each tuple (row).                                                                 | user              | f\n effective_cache_size                   | 524288                                                           | Query Tuning / Planner Cost Constants                             | Sets the planner\'s assumption about the total size of the data caches.                                                                  | user              | f\n jit_above_cost                         | 100000                                                           | Query Tuning / Planner Cost Constants                             | Perform JIT compilation if query is more expensive.                                                                                     | user              | f\n jit_inline_above_cost                  | 500000                                                           | Query Tuning / Planner Cost Constants                             | Perform JIT inlining if query is more expensive.                                                                                        | user              | f\n jit_optimize_above_cost                | 500000                                                           | Query Tuning / Planner Cost Constants                             | Optimize JITed functions if query is more expensive.                                                                                    | user              | f\n min_parallel_index_scan_size           | 64                                                               | Query Tuning / Planner Cost Constants                             | Sets the minimum amount of index data for a parallel scan.                                                                              | user              | f\n min_parallel_table_scan_size           | 1024                                                             | Query Tuning / Planner Cost Constants                             | Sets the minimum amount of table data for a parallel scan.                                                                              | user              | f\n parallel_setup_cost                    | 1000                                                             | Query Tuning / Planner Cost Constants                             | Sets the planner\'s estimate of the cost of starting up worker processes for parallel query.                                             | user              | f\n parallel_tuple_cost                    | 0.1                                                              | Query Tuning / Planner Cost Constants                             | Sets the planner\'s estimate of the cost of passing each tuple (row) from worker to master backend.                                      | user              | f\n random_page_cost                       | 4                                                                | Query Tuning / Planner Cost Constants                             | Sets the planner\'s estimate of the cost of a nonsequentially fetched disk page.                                                         | user              | f\n seq_page_cost                          | 1                                                                | Query Tuning / Planner Cost Constants                             | Sets the planner\'s estimate of the cost of a sequentially fetched disk page.                                                            | user              | f\n enable_bitmapscan                      | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of bitmap-scan plans.                                                                                         | user              | f\n enable_gathermerge                     | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of gather merge plans.                                                                                        | user              | f\n enable_hashagg                         | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of hashed aggregation plans.                                                                                  | user              | f\n enable_hashjoin                        | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of hash join plans.                                                                                           | user              | f\n enable_incremental_sort                | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of incremental sort steps.                                                                                    | user              | f\n enable_indexonlyscan                   | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of index-only-scan plans.                                                                                     | user              | f\n enable_indexscan                       | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of index-scan plans.                                                                                          | user              | f\n enable_material                        | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of materialization.                                                                                           | user              | f\n enable_mergejoin                       | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of merge join plans.                                                                                          | user              | f\n enable_nestloop                        | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of nested-loop join plans.                                                                                    | user              | f\n enable_parallel_append                 | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of parallel append plans.                                                                                     | user              | f\n enable_parallel_hash                   | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of parallel hash plans.                                                                                       | user              | f\n enable_partition_pruning               | on                                                               | Query Tuning / Planner Method Configuration                       | Enables plan-time and run-time partition pruning.                                                                                       | user              | f\n enable_partitionwise_aggregate         | off                                                              | Query Tuning / Planner Method Configuration                       | Enables partitionwise aggregation and grouping.                                                                                         | user              | f\n enable_partitionwise_join              | off                                                              | Query Tuning / Planner Method Configuration                       | Enables partitionwise join.                                                                                                             | user              | f\n enable_seqscan                         | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of sequential-scan plans.                                                                                     | user              | f\n enable_sort                            | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of explicit sort steps.                                                                                       | user              | f\n enable_tidscan                         | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner\'s use of TID scan plans.                                                                                            | user              | f\n track_commit_timestamp                 | off                                                              | Replication                                                       | Collects transaction commit time.                                                                                                       | postmaster        | f\n synchronous_standby_names              | standby                                                          | Replication / Master Server                                       | Number of synchronous standbys and list of names of potential synchronous ones.                                                         | sighup            | f\n vacuum_defer_cleanup_age               | 0                                                                | Replication / Master Server                                       | Number of transactions by which VACUUM and HOT cleanup should be deferred, if any.                                                      | sighup            | f\n max_replication_slots                  | 10                                                               | Replication / Sending Servers                                     | Sets the maximum number of simultaneously defined replication slots.                                                                    | postmaster        | f\n max_slot_wal_keep_size                 | -1                                                               | Replication / Sending Servers                                     | Sets the maximum WAL size that can be reserved by replication slots.                                                                    | sighup            | f\n max_wal_senders                        | 2                                                                | Replication / Sending Servers                                     | Sets the maximum number of simultaneously running WAL sender processes.                                                                 | postmaster        | f\n wal_keep_size                          | 0                                                                | Replication / Sending Servers                                     | Sets the size of WAL files held for standby servers.                                                                                    | sighup            | f\n wal_sender_timeout                     | 60000                                                            | Replication / Sending Servers                                     | Sets the maximum time to wait for WAL replication.                                                                                      | user              | f\n hot_standby                            | on                                                               | Replication / Standby Servers                                     | Allows connections and queries during recovery.                                                                                         | postmaster        | f\n hot_standby_feedback                   | off                                                              | Replication / Standby Servers                                     | Allows feedback from a hot standby to the primary that will avoid query conflicts.                                                      | sighup            | f\n max_standby_archive_delay              | 30000                                                            | Replication / Standby Servers                                     | Sets the maximum delay before canceling queries when a hot standby server is processing archived WAL data.                              | sighup            | f\n max_standby_streaming_delay            | 30000                                                            | Replication / Standby Servers                                     | Sets the maximum delay before canceling queries when a hot standby server is processing streamed WAL data.                              | sighup            | f\n primary_conninfo                       | host=192.168.40.10 port=5432 user=replicator password=replicator | Replication / Standby Servers                                     | Sets the connection string to be used to connect to the sending server.                                                                 | sighup            | f\n primary_slot_name                      | pg_slot_replication                                              | Replication / Standby Servers                                     | Sets the name of the replication slot to use on the sending server.                                                                     | sighup            | f\n promote_trigger_file                   | /tmp/trigger.192.168.40.10.5432                                  | Replication / Standby Servers                                     | Specifies a file name whose presence ends recovery in the standby.                                                                      | sighup            | f\n recovery_min_apply_delay               | 0                                                                | Replication / Standby Servers                                     | Sets the minimum delay for applying changes during recovery.                                                                            | sighup            | f\n wal_receiver_create_temp_slot          | off                                                              | Replication / Standby Servers                                     | Sets whether a WAL receiver should create a temporary replication slot if no permanent slot is configured.                              | sighup            | f\n wal_receiver_status_interval           | 10                                                               | Replication / Standby Servers                                     | Sets the maximum interval between WAL receiver status reports to the sending server.                                                    | sighup            | f\n wal_receiver_timeout                   | 60000                                                            | Replication / Standby Servers                                     | Sets the maximum wait time to receive data from the sending server.                                                                     | sighup            | f\n wal_retrieve_retry_interval            | 5000                                                             | Replication / Standby Servers                                     | Sets the time to wait before retrying to retrieve WAL after a failed attempt.                                                           | sighup            | f\n max_logical_replication_workers        | 4                                                                | Replication / Subscribers                                         | Maximum number of logical replication worker processes.                                                                                 | postmaster        | f\n max_sync_workers_per_subscription      | 2                                                                | Replication / Subscribers                                         | Maximum number of table synchronization workers per subscription.                                                                       | sighup            | f\n application_name                       | psql                                                             | Reporting and Logging / What to Log                               | Sets the application name to be reported in statistics and logs.                                                                        | user              | f\n debug_pretty_print                     | on                                                               | Reporting and Logging / What to Log                               | Indents parse and plan tree displays.                                                                                                   | user              | f\n debug_print_parse                      | off                                                              | Reporting and Logging / What to Log                               | Logs each query\'s parse tree.                                                                                                           | user              | f\n debug_print_plan                       | off                                                              | Reporting and Logging / What to Log                               | Logs each query\'s execution plan.                                                                                                       | user              | f\n debug_print_rewritten                  | off                                                              | Reporting and Logging / What to Log                               | Logs each query\'s rewritten parse tree.                                                                                                 | user              | f\n log_autovacuum_min_duration            | -1                                                               | Reporting and Logging / What to Log                               | Sets the minimum execution time above which autovacuum actions will be logged.                                                          | sighup            | f\n log_checkpoints                        | off                                                              | Reporting and Logging / What to Log                               | Logs each checkpoint.                                                                                                                   | sighup            | f\n log_connections                        | off                                                              | Reporting and Logging / What to Log                               | Logs each successful connection.                                                                                                        | superuser-backend | f\n log_disconnections                     | off                                                              | Reporting and Logging / What to Log                               | Logs end of a session, including duration.                                                                                              | superuser-backend | f\n log_duration                           | off                                                              | Reporting and Logging / What to Log                               | Logs the duration of each completed SQL statement.                                                                                      | superuser         | f\n log_error_verbosity                    | default                                                          | Reporting and Logging / What to Log                               | Sets the verbosity of logged messages.                                                                                                  | superuser         | f\n log_hostname                           | off                                                              | Reporting and Logging / What to Log                               | Logs the host name in the connection logs.                                                                                              | sighup            | f\n log_line_prefix                        | %m [%p]                                                          | Reporting and Logging / What to Log                               | Controls information prefixed to each log line.                                                                                         | sighup            | f\n log_lock_waits                         | off                                                              | Reporting and Logging / What to Log                               | Logs long lock waits.                                                                                                                   | superuser         | f\n log_parameter_max_length               | -1                                                               | Reporting and Logging / What to Log                               | When logging statements, limit logged parameter values to first N bytes.                                                                | superuser         | f\n log_parameter_max_length_on_error      | 0                                                                | Reporting and Logging / What to Log                               | When reporting an error, limit logged parameter values to first N bytes.                                                                | user              | f\n log_replication_commands               | off                                                              | Reporting and Logging / What to Log                               | Logs each replication command.                                                                                                          | superuser         | f\n log_statement                          | none                                                             | Reporting and Logging / What to Log                               | Sets the type of statements logged.                                                                                                     | superuser         | f\n log_temp_files                         | -1                                                               | Reporting and Logging / What to Log                               | Log the use of temporary files larger than this number of kilobytes.                                                                    | superuser         | f\n log_timezone                           | UTC                                                              | Reporting and Logging / What to Log                               | Sets the time zone to use in log messages.                                                                                              | sighup            | f\n log_min_duration_sample                | -1                                                               | Reporting and Logging / When to Log                               | Sets the minimum execution time above which a sample of statements will be logged. Sampling is determined by log_statement_sample_rate. | superuser         | f\n log_min_duration_statement             | -1                                                               | Reporting and Logging / When to Log                               | Sets the minimum execution time above which all statements will be logged.                                                              | superuser         | f\n log_min_error_statement                | error                                                            | Reporting and Logging / When to Log                               | Causes all statements generating error at or above this level to be logged.                                                             | superuser         | f\n log_min_messages                       | warning                                                          | Reporting and Logging / When to Log                               | Sets the message levels that are logged.                                                                                                | superuser         | f\n log_statement_sample_rate              | 1                                                                | Reporting and Logging / When to Log                               | Fraction of statements exceeding log_min_duration_sample to be logged.                                                                  | superuser         | f\n log_transaction_sample_rate            | 0                                                                | Reporting and Logging / When to Log                               | Set the fraction of transactions to log for new transactions.                                                                           | superuser         | f\n event_source                           | PostgreSQL                                                       | Reporting and Logging / Where to Log                              | Sets the application name used to identify PostgreSQL messages in the event log.                                                        | postmaster        | f\n log_destination                        | stderr                                                           | Reporting and Logging / Where to Log                              | Sets the destination for server log output.                                                                                             | sighup            | f\n log_directory                          | log                                                              | Reporting and Logging / Where to Log                              | Sets the destination directory for log files.                                                                                           | sighup            | f\n log_file_mode                          | 0600                                                             | Reporting and Logging / Where to Log                              | Sets the file permissions for log files.                                                                                                | sighup            | f\n log_filename                           | postgresql-%a.log                                                | Reporting and Logging / Where to Log                              | Sets the file name pattern for log files.                                                                                               | sighup            | f\n logging_collector                      | on                                                               | Reporting and Logging / Where to Log                              | Start a subprocess to capture stderr output and/or csvlogs into log files.                                                              | postmaster        | f\n log_rotation_age                       | 1440                                                             | Reporting and Logging / Where to Log                              | Automatic log file rotation will occur after N minutes.                                                                                 | sighup            | f\n log_rotation_size                      | 0                                                                | Reporting and Logging / Where to Log                              | Automatic log file rotation will occur after N kilobytes.                                                                               | sighup            | f\n log_truncate_on_rotation               | on                                                               | Reporting and Logging / Where to Log                              | Truncate existing log files of same name during log rotation.                                                                           | sighup            | f\n syslog_facility                        | local0                                                           | Reporting and Logging / Where to Log                              | Sets the syslog "facility" to be used when syslog enabled.                                                                              | sighup            | f\n syslog_ident                           | postgres                                                         | Reporting and Logging / Where to Log                              | Sets the program name used to identify PostgreSQL messages in syslog.                                                                   | sighup            | f\n syslog_sequence_numbers                | on                                                               | Reporting and Logging / Where to Log                              | Add sequence number to syslog messages to avoid duplicate suppression.                                                                  | sighup            | f\n syslog_split_messages                  | on                                                               | Reporting and Logging / Where to Log                              | Split messages sent to syslog by lines and to fit into 1024 bytes.                                                                      | sighup            | f\n backend_flush_after                    | 0                                                                | Resource Usage / Asynchronous Behavior                            | Number of pages after which previously performed writes are flushed to disk.                                                            | user              | f\n effective_io_concurrency               | 1                                                                | Resource Usage / Asynchronous Behavior                            | Number of simultaneous requests that can be handled efficiently by the disk subsystem.                                                  | user              | f\n maintenance_io_concurrency             | 10                                                               | Resource Usage / Asynchronous Behavior                            | A variant of effective_io_concurrency that is used for maintenance work.                                                                | user              | f\n max_parallel_maintenance_workers       | 2                                                                | Resource Usage / Asynchronous Behavior                            | Sets the maximum number of parallel processes per maintenance operation.                                                                | user              | f\n max_parallel_workers                   | 8                                                                | Resource Usage / Asynchronous Behavior                            | Sets the maximum number of parallel workers that can be active at one time.                                                             | user              | f\n max_parallel_workers_per_gather        | 2                                                                | Resource Usage / Asynchronous Behavior                            | Sets the maximum number of parallel processes per executor node.                                                                        | user              | f\n max_worker_processes                   | 8                                                                | Resource Usage / Asynchronous Behavior                            | Maximum number of concurrent worker processes.                                                                                          | postmaster        | f\n old_snapshot_threshold                 | -1                                                               | Resource Usage / Asynchronous Behavior                            | Time before a snapshot is too old to read pages changed after the snapshot was taken.                                                   | postmaster        | f\n parallel_leader_participation          | on                                                               | Resource Usage / Asynchronous Behavior                            | Controls whether Gather and Gather Merge also run subplans.                                                                             | user              | f\n bgwriter_delay                         | 200                                                              | Resource Usage / Background Writer                                | Background writer sleep time between rounds.                                                                                            | sighup            | f\n bgwriter_flush_after                   | 64                                                               | Resource Usage / Background Writer                                | Number of pages after which previously performed writes are flushed to disk.                                                            | sighup            | f\n bgwriter_lru_maxpages                  | 100                                                              | Resource Usage / Background Writer                                | Background writer maximum number of LRU pages to flush per round.                                                                       | sighup            | f\n bgwriter_lru_multiplier                | 2                                                                | Resource Usage / Background Writer                                | Multiple of the average buffer usage to free per round.                                                                                 | sighup            | f\n vacuum_cost_delay                      | 0                                                                | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost delay in milliseconds.                                                                                                      | user              | f\n vacuum_cost_limit                      | 200                                                              | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost amount available before napping.                                                                                            | user              | f\n vacuum_cost_page_dirty                 | 20                                                               | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost for a page dirtied by vacuum.                                                                                               | user              | f\n vacuum_cost_page_hit                   | 1                                                                | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost for a page found in the buffer cache.                                                                                       | user              | f\n vacuum_cost_page_miss                  | 10                                                               | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost for a page not found in the buffer cache.                                                                                   | user              | f\n temp_file_limit                        | -1                                                               | Resource Usage / Disk                                             | Limits the total size of all temporary files used by each process.                                                                      | superuser         | f\n max_files_per_process                  | 1000                                                             | Resource Usage / Kernel Resources                                 | Sets the maximum number of simultaneously open files for each server process.                                                           | postmaster        | f\n autovacuum_work_mem                    | -1                                                               | Resource Usage / Memory                                           | Sets the maximum memory to be used by each autovacuum worker process.                                                                   | sighup            | f\n dynamic_shared_memory_type             | posix                                                            | Resource Usage / Memory                                           | Selects the dynamic shared memory implementation used.                                                                                  | postmaster        | f\n hash_mem_multiplier                    | 1                                                                | Resource Usage / Memory                                           | Multiple of work_mem to use for hash tables.                                                                                            | user              | f\n huge_pages                             | try                                                              | Resource Usage / Memory                                           | Use of huge pages on Linux or Windows.                                                                                                  | postmaster        | f\n logical_decoding_work_mem              | 65536                                                            | Resource Usage / Memory                                           | Sets the maximum memory to be used for logical decoding.                                                                                | user              | f\n maintenance_work_mem                   | 65536                                                            | Resource Usage / Memory                                           | Sets the maximum memory to be used for maintenance operations.                                                                          | user              | f\n max_prepared_transactions              | 0                                                                | Resource Usage / Memory                                           | Sets the maximum number of simultaneously prepared transactions.                                                                        | postmaster        | f\n max_stack_depth                        | 2048                                                             | Resource Usage / Memory                                           | Sets the maximum stack depth, in kilobytes.                                                                                             | superuser         | f\n shared_buffers                         | 16384                                                            | Resource Usage / Memory                                           | Sets the number of shared memory buffers used by the server.                                                                            | postmaster        | f\n shared_memory_type                     | mmap                                                             | Resource Usage / Memory                                           | Selects the shared memory implementation used for the main shared memory region.                                                        | postmaster        | f\n temp_buffers                           | 1024                                                             | Resource Usage / Memory                                           | Sets the maximum number of temporary buffers used by each session.                                                                      | user              | f\n track_activity_query_size              | 1024                                                             | Resource Usage / Memory                                           | Sets the size reserved for pg_stat_activity.query, in bytes.                                                                            | postmaster        | f\n work_mem                               | 4096                                                             | Resource Usage / Memory                                           | Sets the maximum memory to be used for query workspaces.                                                                                | user              | f\n log_executor_stats                     | off                                                              | Statistics / Monitoring                                           | Writes executor performance statistics to the server log.                                                                               | superuser         | f\n log_parser_stats                       | off                                                              | Statistics / Monitoring                                           | Writes parser performance statistics to the server log.                                                                                 | superuser         | f\n log_planner_stats                      | off                                                              | Statistics / Monitoring                                           | Writes planner performance statistics to the server log.                                                                                | superuser         | f\n log_statement_stats                    | off                                                              | Statistics / Monitoring                                           | Writes cumulative performance statistics to the server log.                                                                             | superuser         | f\n stats_temp_directory                   | pg_stat_tmp                                                      | Statistics / Query and Index Statistics Collector                 | Writes temporary statistics files to the specified directory.                                                                           | sighup            | f\n track_activities                       | on                                                               | Statistics / Query and Index Statistics Collector                 | Collects information about executing commands.                                                                                          | superuser         | f\n track_counts                           | on                                                               | Statistics / Query and Index Statistics Collector                 | Collects statistics on database activity.                                                                                               | superuser         | f\n track_functions                        | none                                                             | Statistics / Query and Index Statistics Collector                 | Collects function-level statistics on database activity.                                                                                | superuser         | f\n track_io_timing                        | off                                                              | Statistics / Query and Index Statistics Collector                 | Collects timing statistics for database I/O activity.                                                                                   | superuser         | f\n transform_null_equals                  | off                                                              | Version and Platform Compatibility / Other Platforms and Clients  | Treats "expr=NULL" as "expr IS NULL".                                                                                                   | user              | f\n array_nulls                            | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Enable input of NULL elements in arrays.                                                                                                | user              | f\n backslash_quote                        | safe_encoding                                                    | Version and Platform Compatibility / Previous PostgreSQL Versions | Sets whether "\\\'" is allowed in string literals.                                                                                        | user              | f\n escape_string_warning                  | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Warn about backslash escapes in ordinary string literals.                                                                               | user              | f\n lo_compat_privileges                   | off                                                              | Version and Platform Compatibility / Previous PostgreSQL Versions | Enables backward compatibility mode for privilege checks on large objects.                                                              | superuser         | f\n operator_precedence_warning            | off                                                              | Version and Platform Compatibility / Previous PostgreSQL Versions | Emit a warning for constructs that changed meaning since PostgreSQL 9.4.                                                                | user              | f\n quote_all_identifiers                  | off                                                              | Version and Platform Compatibility / Previous PostgreSQL Versions | When generating SQL fragments, quote all identifiers.                                                                                   | user              | f\n standard_conforming_strings            | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Causes \'...\' strings to treat backslashes literally.                                                                                    | user              | f\n synchronize_seqscans                   | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Enable synchronized sequential scans.                                                                                                   | user              | f\n archive_cleanup_command                |                                                                  | Write-Ahead Log / Archive Recovery                                | Sets the shell command that will be executed at every restart point.                                                                    | sighup            | f\n recovery_end_command                   |                                                                  | Write-Ahead Log / Archive Recovery                                | Sets the shell command that will be executed once at the end of recovery.                                                               | sighup            | f\n restore_command                        |                                                                  | Write-Ahead Log / Archive Recovery                                | Sets the shell command that will be called to retrieve an archived WAL file.                                                            | postmaster        | f\n archive_command                        |                                                                  | Write-Ahead Log / Archiving                                       | Sets the shell command that will be called to archive a WAL file.                                                                       | sighup            | f\n archive_mode                           | on                                                               | Write-Ahead Log / Archiving                                       | Allows archiving of WAL files using archive_command.                                                                                    | postmaster        | f\n archive_timeout                        | 0                                                                | Write-Ahead Log / Archiving                                       | Forces a switch to the next WAL file if a new file has not been started within N seconds.                                               | sighup            | f\n checkpoint_completion_target           | 0.5                                                              | Write-Ahead Log / Checkpoints                                     | Time spent flushing dirty buffers during checkpoint, as fraction of checkpoint interval.                                                | sighup            | f\n checkpoint_flush_after                 | 32                                                               | Write-Ahead Log / Checkpoints                                     | Number of pages after which previously performed writes are flushed to disk.                                                            | sighup            | f\n checkpoint_timeout                     | 300                                                              | Write-Ahead Log / Checkpoints                                     | Sets the maximum time between automatic WAL checkpoints.                                                                                | sighup            | f\n checkpoint_warning                     | 30                                                               | Write-Ahead Log / Checkpoints                                     | Enables warnings if checkpoint segments are filled more frequently than this.                                                           | sighup            | f\n max_wal_size                           | 1024                                                             | Write-Ahead Log / Checkpoints                                     | Sets the WAL size that triggers a checkpoint.                                                                                           | sighup            | f\n min_wal_size                           | 80                                                               | Write-Ahead Log / Checkpoints                                     | Sets the minimum size to shrink the WAL to.                                                                                             | sighup            | f\n recovery_target                        |                                                                  | Write-Ahead Log / Recovery Target                                 | Set to "immediate" to end recovery as soon as a consistent state is reached.                                                            | postmaster        | f\n recovery_target_action                 | pause                                                            | Write-Ahead Log / Recovery Target                                 | Sets the action to perform upon reaching the recovery target.                                                                           | postmaster        | f\n recovery_target_inclusive              | on                                                               | Write-Ahead Log / Recovery Target                                 | Sets whether to include or exclude transaction with recovery target.                                                                    | postmaster        | f\n recovery_target_lsn                    |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the LSN of the write-ahead log location up to which recovery will proceed.                                                         | postmaster        | f\n recovery_target_name                   |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the named restore point up to which recovery will proceed.                                                                         | postmaster        | f\n recovery_target_time                   |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the time stamp up to which recovery will proceed.                                                                                  | postmaster        | f\n recovery_target_timeline               | latest                                                           | Write-Ahead Log / Recovery Target                                 | Specifies the timeline to recover into.                                                                                                 | postmaster        | f\n recovery_target_xid                    |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the transaction ID up to which recovery will proceed.                                                                              | postmaster        | f\n commit_delay                           | 0                                                                | Write-Ahead Log / Settings                                        | Sets the delay in microseconds between transaction commit and flushing WAL to disk.                                                     | superuser         | f\n commit_siblings                        | 5                                                                | Write-Ahead Log / Settings                                        | Sets the minimum concurrent open transactions before performing commit_delay.                                                           | user              | f\n fsync                                  | on                                                               | Write-Ahead Log / Settings                                        | Forces synchronization of updates to disk.                                                                                              | sighup            | f\n full_page_writes                       | on                                                               | Write-Ahead Log / Settings                                        | Writes full pages to WAL when first modified after a checkpoint.                                                                        | sighup            | f\n synchronous_commit                     | local                                                            | Write-Ahead Log / Settings                                        | Sets the current transaction\'s synchronization level.                                                                                   | user              | f\n wal_buffers                            | 512                                                              | Write-Ahead Log / Settings                                        | Sets the number of disk-page buffers in shared memory for WAL.                                                                          | postmaster        | f\n wal_compression                        | off                                                              | Write-Ahead Log / Settings                                        | Compresses full-page writes written in WAL file.                                                                                        | superuser         | f\n wal_init_zero                          | on                                                               | Write-Ahead Log / Settings                                        | Writes zeroes to new WAL files before first use.                                                                                        | superuser         | f\n wal_level                              | replica                                                          | Write-Ahead Log / Settings                                        | Set the level of information written to the WAL.                                                                                        | postmaster        | f\n wal_log_hints                          | off                                                              | Write-Ahead Log / Settings                                        | Writes full pages to WAL when first modified after a checkpoint, even for a non-critical modification.                                  | postmaster        | f\n wal_recycle                            | on                                                               | Write-Ahead Log / Settings                                        | Recycles WAL files by renaming them.                                                                                                    | superuser         | f\n wal_skip_threshold                     | 2048                                                             | Write-Ahead Log / Settings                                        | Size of new file to fsync instead of writing WAL.                                                                                       | user              | f\n wal_sync_method                        | fdatasync                                                        | Write-Ahead Log / Settings                                        | Selects the method used for forcing WAL updates to disk.                                                                                | sighup            | f\n wal_writer_delay                       | 200                                                              | Write-Ahead Log / Settings                                        | Time between WAL flushes performed in the WAL writer.                                                                                   | sighup            | f\n wal_writer_flush_after                 | 128                                                              | Write-Ahead Log / Settings                                        | Amount of WAL written out by WAL writer that triggers a flush.                                                                          | sighup            | f\n(329 строк)', 'cmd': 'sudo -iu postgres psql -c "SELECT name, setting, category, short_desc, context, pending_restart FROM pg_catalog.pg_settings ORDER BY category, name;"', 'rc': 0, 'start': '2025-02-19 17:49:47.884822', 'stderr': '', 'delta': '0:00:00.132229', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT name, setting, category, short_desc, context, pending_restart FROM pg_catalog.pg_settings ORDER BY category, name;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['                  name                  |                             setting                              |                             category                              |                                                               short_desc                                                                |      context      | pending_restart ', '----------------------------------------+------------------------------------------------------------------+-------------------------------------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------+-------------------+-----------------', ' autovacuum                             | on                                                               | Autovacuum                                                        | Starts the autovacuum subprocess.                                                                                                       | sighup            | f', ' autovacuum_analyze_scale_factor        | 0.1                                                              | Autovacuum                                                        | Number of tuple inserts, updates, or deletes prior to analyze as a fraction of reltuples.                                               | sighup            | f', ' autovacuum_analyze_threshold           | 50                                                               | Autovacuum                                                        | Minimum number of tuple inserts, updates, or deletes prior to analyze.                                                                  | sighup            | f', ' autovacuum_freeze_max_age              | 200000000                                                        | Autovacuum                                                        | Age at which to autovacuum a table to prevent transaction ID wraparound.                                                                | postmaster        | f', ' autovacuum_max_workers                 | 3                                                                | Autovacuum                                                        | Sets the maximum number of simultaneously running autovacuum worker processes.                                                          | postmaster        | f', ' autovacuum_multixact_freeze_max_age    | 400000000                                                        | Autovacuum                                                        | Multixact age at which to autovacuum a table to prevent multixact wraparound.                                                           | postmaster        | f', ' autovacuum_naptime                     | 60                                                               | Autovacuum                                                        | Time to sleep between autovacuum runs.                                                                                                  | sighup            | f', ' autovacuum_vacuum_cost_delay           | 2                                                                | Autovacuum                                                        | Vacuum cost delay in milliseconds, for autovacuum.                                                                                      | sighup            | f', ' autovacuum_vacuum_cost_limit           | -1                                                               | Autovacuum                                                        | Vacuum cost amount available before napping, for autovacuum.                                                                            | sighup            | f', ' autovacuum_vacuum_insert_scale_factor  | 0.2                                                              | Autovacuum                                                        | Number of tuple inserts prior to vacuum as a fraction of reltuples.                                                                     | sighup            | f', ' autovacuum_vacuum_insert_threshold     | 1000                                                             | Autovacuum                                                        | Minimum number of tuple inserts prior to vacuum, or -1 to disable insert vacuums.                                                       | sighup            | f', ' autovacuum_vacuum_scale_factor         | 0.2                                                              | Autovacuum                                                        | Number of tuple updates or deletes prior to vacuum as a fraction of reltuples.                                                          | sighup            | f', ' autovacuum_vacuum_threshold            | 50                                                               | Autovacuum                                                        | Minimum number of tuple updates or deletes prior to vacuum.                                                                             | sighup            | f', " client_encoding                        | UTF8                                                             | Client Connection Defaults / Locale and Formatting                | Sets the client's character set encoding.                                                                                               | user              | f", ' DateStyle                              | ISO, MDY                                                         | Client Connection Defaults / Locale and Formatting                | Sets the display format for date and time values.                                                                                       | user              | f', ' default_text_search_config             | pg_catalog.english                                               | Client Connection Defaults / Locale and Formatting                | Sets default text search configuration.                                                                                                 | user              | f', ' extra_float_digits                     | 1                                                                | Client Connection Defaults / Locale and Formatting                | Sets the number of digits displayed for floating-point values.                                                                          | user              | f', ' IntervalStyle                          | postgres                                                         | Client Connection Defaults / Locale and Formatting                | Sets the display format for interval values.                                                                                            | user              | f', ' lc_collate                             | en_US.UTF-8                                                      | Client Connection Defaults / Locale and Formatting                | Shows the collation order locale.                                                                                                       | internal          | f', ' lc_ctype                               | en_US.UTF-8                                                      | Client Connection Defaults / Locale and Formatting                | Shows the character classification and case conversion locale.                                                                          | internal          | f', ' lc_messages                            | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the language in which messages are displayed.                                                                                      | superuser         | f', ' lc_monetary                            | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the locale for formatting monetary amounts.                                                                                        | user              | f', ' lc_numeric                             | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the locale for formatting numbers.                                                                                                 | user              | f', ' lc_time                                | en_US.utf8                                                       | Client Connection Defaults / Locale and Formatting                | Sets the locale for formatting date and time values.                                                                                    | user              | f', ' server_encoding                        | UTF8                                                             | Client Connection Defaults / Locale and Formatting                | Sets the server (database) character set encoding.                                                                                      | internal          | f', ' TimeZone                               | UTC                                                              | Client Connection Defaults / Locale and Formatting                | Sets the time zone for displaying and interpreting time stamps.                                                                         | user              | f', ' timezone_abbreviations                 | Default                                                          | Client Connection Defaults / Locale and Formatting                | Selects a file of time zone abbreviations.                                                                                              | user              | f', ' dynamic_library_path                   | $libdir                                                          | Client Connection Defaults / Other Defaults                       | Sets the path for dynamically loadable modules.                                                                                         | superuser         | f', ' gin_fuzzy_search_limit                 | 0                                                                | Client Connection Defaults / Other Defaults                       | Sets the maximum allowed result for exact search by GIN.                                                                                | user              | f', ' tcp_keepalives_count                   | 0                                                                | Client Connection Defaults / Other Defaults                       | Maximum number of TCP keepalive retransmits.                                                                                            | user              | f', ' tcp_keepalives_idle                    | 0                                                                | Client Connection Defaults / Other Defaults                       | Time between issuing TCP keepalives.                                                                                                    | user              | f', ' tcp_keepalives_interval                | 0                                                                | Client Connection Defaults / Other Defaults                       | Time between TCP keepalive retransmits.                                                                                                 | user              | f', ' tcp_user_timeout                       | 0                                                                | Client Connection Defaults / Other Defaults                       | TCP user timeout.                                                                                                                       | user              | f', ' jit_provider                           | llvmjit                                                          | Client Connection Defaults / Shared Library Preloading            | JIT provider to use.                                                                                                                    | postmaster        | f', ' local_preload_libraries                |                                                                  | Client Connection Defaults / Shared Library Preloading            | Lists unprivileged shared libraries to preload into each backend.                                                                       | user              | f', ' session_preload_libraries              |                                                                  | Client Connection Defaults / Shared Library Preloading            | Lists shared libraries to preload into each backend.                                                                                    | superuser         | f', ' shared_preload_libraries               |                                                                  | Client Connection Defaults / Shared Library Preloading            | Lists shared libraries to preload into server.                                                                                          | postmaster        | f', ' bytea_output                           | hex                                                              | Client Connection Defaults / Statement Behavior                   | Sets the output format for bytea.                                                                                                       | user              | f', ' check_function_bodies                  | on                                                               | Client Connection Defaults / Statement Behavior                   | Check function bodies during CREATE FUNCTION.                                                                                           | user              | f', ' client_min_messages                    | notice                                                           | Client Connection Defaults / Statement Behavior                   | Sets the message levels that are sent to the client.                                                                                    | user              | f', ' default_table_access_method            | heap                                                             | Client Connection Defaults / Statement Behavior                   | Sets the default table access method for new tables.                                                                                    | user              | f', ' default_tablespace                     |                                                                  | Client Connection Defaults / Statement Behavior                   | Sets the default tablespace to create tables and indexes in.                                                                            | user              | f', ' default_transaction_deferrable         | off                                                              | Client Connection Defaults / Statement Behavior                   | Sets the default deferrable status of new transactions.                                                                                 | user              | f', ' default_transaction_isolation          | read committed                                                   | Client Connection Defaults / Statement Behavior                   | Sets the transaction isolation level of each new transaction.                                                                           | user              | f', ' default_transaction_read_only          | off                                                              | Client Connection Defaults / Statement Behavior                   | Sets the default read-only status of new transactions.                                                                                  | user              | f', ' gin_pending_list_limit                 | 4096                                                             | Client Connection Defaults / Statement Behavior                   | Sets the maximum size of the pending list for GIN index.                                                                                | user              | f', ' idle_in_transaction_session_timeout    | 0                                                                | Client Connection Defaults / Statement Behavior                   | Sets the maximum allowed duration of any idling transaction.                                                                            | user              | f', ' lock_timeout                           | 0                                                                | Client Connection Defaults / Statement Behavior                   | Sets the maximum allowed duration of any wait for a lock.                                                                               | user              | f', ' row_security                           | on                                                               | Client Connection Defaults / Statement Behavior                   | Enable row security.                                                                                                                    | user              | f', ' search_path                            | "$user", public                                                  | Client Connection Defaults / Statement Behavior                   | Sets the schema search order for names that are not schema-qualified.                                                                   | user              | f', " session_replication_role               | origin                                                           | Client Connection Defaults / Statement Behavior                   | Sets the session's behavior for triggers and rewrite rules.                                                                             | superuser         | f", ' statement_timeout                      | 0                                                                | Client Connection Defaults / Statement Behavior                   | Sets the maximum allowed duration of any statement.                                                                                     | user              | f', ' temp_tablespaces                       |                                                                  | Client Connection Defaults / Statement Behavior                   | Sets the tablespace(s) to use for temporary tables and sort files.                                                                      | user              | f', ' transaction_deferrable                 | off                                                              | Client Connection Defaults / Statement Behavior                   | Whether to defer a read-only serializable transaction until it can be executed with no possible serialization failures.                 | user              | f', " transaction_isolation                  | read committed                                                   | Client Connection Defaults / Statement Behavior                   | Sets the current transaction's isolation level.                                                                                         | user              | f", " transaction_read_only                  | on                                                               | Client Connection Defaults / Statement Behavior                   | Sets the current transaction's read-only status.                                                                                        | user              | f", ' vacuum_cleanup_index_scale_factor      | 0.1                                                              | Client Connection Defaults / Statement Behavior                   | Number of tuple inserts prior to index cleanup as a fraction of reltuples.                                                              | user              | f', ' vacuum_freeze_min_age                  | 50000000                                                         | Client Connection Defaults / Statement Behavior                   | Minimum age at which VACUUM should freeze a table row.                                                                                  | user              | f', ' vacuum_freeze_table_age                | 150000000                                                        | Client Connection Defaults / Statement Behavior                   | Age at which VACUUM should scan whole table to freeze tuples.                                                                           | user              | f', ' vacuum_multixact_freeze_min_age        | 5000000                                                          | Client Connection Defaults / Statement Behavior                   | Minimum age at which VACUUM should freeze a MultiXactId in a table row.                                                                 | user              | f', ' vacuum_multixact_freeze_table_age      | 150000000                                                        | Client Connection Defaults / Statement Behavior                   | Multixact age at which VACUUM should scan whole table to freeze tuples.                                                                 | user              | f', ' xmlbinary                              | base64                                                           | Client Connection Defaults / Statement Behavior                   | Sets how binary values are to be encoded in XML.                                                                                        | user              | f', ' xmloption                              | content                                                          | Client Connection Defaults / Statement Behavior                   | Sets whether XML data in implicit parsing and serialization operations is to be considered as documents or content fragments.           | user              | f', ' authentication_timeout                 | 60                                                               | Connections and Authentication / Authentication                   | Sets the maximum allowed time to complete client authentication.                                                                        | sighup            | f', ' db_user_namespace                      | off                                                              | Connections and Authentication / Authentication                   | Enables per-database user names.                                                                                                        | sighup            | f', ' krb_caseins_users                      | off                                                              | Connections and Authentication / Authentication                   | Sets whether Kerberos and GSSAPI user names should be treated as case-insensitive.                                                      | sighup            | f', ' krb_server_keyfile                     | FILE:/etc/sysconfig/pgsql/krb5.keytab                            | Connections and Authentication / Authentication                   | Sets the location of the Kerberos server key file.                                                                                      | sighup            | f', ' password_encryption                    | md5                                                              | Connections and Authentication / Authentication                   | Chooses the algorithm for encrypting passwords.                                                                                         | user              | f', ' bonjour                                | off                                                              | Connections and Authentication / Connection Settings              | Enables advertising the server via Bonjour.                                                                                             | postmaster        | f', ' bonjour_name                           |                                                                  | Connections and Authentication / Connection Settings              | Sets the Bonjour service name.                                                                                                          | postmaster        | f', ' listen_addresses                       | 192.168.40.11,localhost                                          | Connections and Authentication / Connection Settings              | Sets the host name or IP address(es) to listen to.                                                                                      | postmaster        | f', ' max_connections                        | 100                                                              | Connections and Authentication / Connection Settings              | Sets the maximum number of concurrent connections.                                                                                      | postmaster        | f', ' port                                   | 5432                                                             | Connections and Authentication / Connection Settings              | Sets the TCP port the server listens on.                                                                                                | postmaster        | f', ' superuser_reserved_connections         | 3                                                                | Connections and Authentication / Connection Settings              | Sets the number of connection slots reserved for superusers.                                                                            | postmaster        | f', ' unix_socket_directories                | /var/run/postgresql, /tmp                                        | Connections and Authentication / Connection Settings              | Sets the directories where Unix-domain sockets will be created.                                                                         | postmaster        | f', ' unix_socket_group                      |                                                                  | Connections and Authentication / Connection Settings              | Sets the owning group of the Unix-domain socket.                                                                                        | postmaster        | f', ' unix_socket_permissions                | 0777                                                             | Connections and Authentication / Connection Settings              | Sets the access permissions of the Unix-domain socket.                                                                                  | postmaster        | f', ' ssl                                    | off                                                              | Connections and Authentication / SSL                              | Enables SSL connections.                                                                                                                | sighup            | f', ' ssl_ca_file                            |                                                                  | Connections and Authentication / SSL                              | Location of the SSL certificate authority file.                                                                                         | sighup            | f', ' ssl_cert_file                          | server.crt                                                       | Connections and Authentication / SSL                              | Location of the SSL server certificate file.                                                                                            | sighup            | f', ' ssl_ciphers                            | HIGH:MEDIUM:+3DES:!aNULL                                         | Connections and Authentication / SSL                              | Sets the list of allowed SSL ciphers.                                                                                                   | sighup            | f', ' ssl_crl_file                           |                                                                  | Connections and Authentication / SSL                              | Location of the SSL certificate revocation list file.                                                                                   | sighup            | f', ' ssl_dh_params_file                     |                                                                  | Connections and Authentication / SSL                              | Location of the SSL DH parameters file.                                                                                                 | sighup            | f', ' ssl_ecdh_curve                         | prime256v1                                                       | Connections and Authentication / SSL                              | Sets the curve to use for ECDH.                                                                                                         | sighup            | f', ' ssl_key_file                           | server.key                                                       | Connections and Authentication / SSL                              | Location of the SSL server private key file.                                                                                            | sighup            | f', ' ssl_max_protocol_version               |                                                                  | Connections and Authentication / SSL                              | Sets the maximum SSL/TLS protocol version to use.                                                                                       | sighup            | f', ' ssl_min_protocol_version               | TLSv1.2                                                          | Connections and Authentication / SSL                              | Sets the minimum SSL/TLS protocol version to use.                                                                                       | sighup            | f', ' ssl_passphrase_command                 |                                                                  | Connections and Authentication / SSL                              | Command to obtain passphrases for SSL.                                                                                                  | sighup            | f', ' ssl_passphrase_command_supports_reload | off                                                              | Connections and Authentication / SSL                              | Also use ssl_passphrase_command during server reload.                                                                                   | sighup            | f', ' ssl_prefer_server_ciphers              | on                                                               | Connections and Authentication / SSL                              | Give priority to server ciphersuite order.                                                                                              | sighup            | f', ' allow_system_table_mods                | off                                                              | Developer Options                                                 | Allows modifications of the structure of system tables.                                                                                 | superuser         | f', ' backtrace_functions                    |                                                                  | Developer Options                                                 | Log backtrace for errors in these functions.                                                                                            | superuser         | f', ' ignore_checksum_failure                | off                                                              | Developer Options                                                 | Continues processing after a checksum failure.                                                                                          | superuser         | f', ' ignore_invalid_pages                   | off                                                              | Developer Options                                                 | Continues recovery after an invalid pages failure.                                                                                      | postmaster        | f', ' ignore_system_indexes                  | off                                                              | Developer Options                                                 | Disables reading from system indexes.                                                                                                   | backend           | f', ' jit_debugging_support                  | off                                                              | Developer Options                                                 | Register JIT compiled function with debugger.                                                                                           | superuser-backend | f', ' jit_dump_bitcode                       | off                                                              | Developer Options                                                 | Write out LLVM bitcode to facilitate JIT debugging.                                                                                     | superuser         | f', ' jit_expressions                        | on                                                               | Developer Options                                                 | Allow JIT compilation of expressions.                                                                                                   | user              | f', ' jit_profiling_support                  | off                                                              | Developer Options                                                 | Register JIT compiled function with perf profiler.                                                                                      | superuser-backend | f', ' jit_tuple_deforming                    | on                                                               | Developer Options                                                 | Allow JIT compilation of tuple deforming.                                                                                               | user              | f', ' post_auth_delay                        | 0                                                                | Developer Options                                                 | Waits N seconds on connection startup after authentication.                                                                             | backend           | f', ' pre_auth_delay                         | 0                                                                | Developer Options                                                 | Waits N seconds on connection startup before authentication.                                                                            | sighup            | f', ' trace_notify                           | off                                                              | Developer Options                                                 | Generates debugging output for LISTEN and NOTIFY.                                                                                       | user              | f', ' trace_recovery_messages                | log                                                              | Developer Options                                                 | Enables logging of recovery-related debugging information.                                                                              | sighup            | f', ' trace_sort                             | off                                                              | Developer Options                                                 | Emit information about resource usage in sorting.                                                                                       | user              | f', ' wal_consistency_checking               |                                                                  | Developer Options                                                 | Sets the WAL resource managers for which WAL consistency checks are done.                                                               | superuser         | f', ' zero_damaged_pages                     | off                                                              | Developer Options                                                 | Continues processing past damaged page headers.                                                                                         | superuser         | f', ' data_sync_retry                        | off                                                              | Error Handling                                                    | Whether to continue running after a failure to sync data files.                                                                         | postmaster        | f', ' exit_on_error                          | off                                                              | Error Handling                                                    | Terminate session on any error.                                                                                                         | user              | f', ' restart_after_crash                    | on                                                               | Error Handling                                                    | Reinitialize server after backend crash.                                                                                                | sighup            | f', " config_file                            | /var/lib/pgsql/13/data/postgresql.conf                           | File Locations                                                    | Sets the server's main configuration file.                                                                                              | postmaster        | f", " data_directory                         | /var/lib/pgsql/13/data                                           | File Locations                                                    | Sets the server's data directory.                                                                                                       | postmaster        | f", ' external_pid_file                      |                                                                  | File Locations                                                    | Writes the postmaster PID to the specified file.                                                                                        | postmaster        | f', ' hba_file                               | /var/lib/pgsql/13/data/pg_hba.conf                               | File Locations                                                    | Sets the server\'s "hba" configuration file.                                                                                             | postmaster        | f', ' ident_file                             | /var/lib/pgsql/13/data/pg_ident.conf                             | File Locations                                                    | Sets the server\'s "ident" configuration file.                                                                                           | postmaster        | f', ' deadlock_timeout                       | 1000                                                             | Lock Management                                                   | Sets the time to wait on a lock before checking for deadlock.                                                                           | superuser         | f', ' max_locks_per_transaction              | 64                                                               | Lock Management                                                   | Sets the maximum number of locks per transaction.                                                                                       | postmaster        | f', ' max_pred_locks_per_page                | 2                                                                | Lock Management                                                   | Sets the maximum number of predicate-locked tuples per page.                                                                            | sighup            | f', ' max_pred_locks_per_relation            | -2                                                               | Lock Management                                                   | Sets the maximum number of predicate-locked pages and tuples per relation.                                                              | sighup            | f', ' max_pred_locks_per_transaction         | 64                                                               | Lock Management                                                   | Sets the maximum number of predicate locks per transaction.                                                                             | postmaster        | f', ' block_size                             | 8192                                                             | Preset Options                                                    | Shows the size of a disk block.                                                                                                         | internal          | f', ' data_checksums                         | off                                                              | Preset Options                                                    | Shows whether data checksums are turned on for this cluster.                                                                            | internal          | f', ' data_directory_mode                    | 0700                                                             | Preset Options                                                    | Mode of the data directory.                                                                                                             | internal          | f', ' debug_assertions                       | off                                                              | Preset Options                                                    | Shows whether the running server has assertion checks enabled.                                                                          | internal          | f', ' integer_datetimes                      | on                                                               | Preset Options                                                    | Datetimes are integer based.                                                                                                            | internal          | f', ' max_function_args                      | 100                                                              | Preset Options                                                    | Shows the maximum number of function arguments.                                                                                         | internal          | f', ' max_identifier_length                  | 63                                                               | Preset Options                                                    | Shows the maximum identifier length.                                                                                                    | internal          | f', ' max_index_keys                         | 32                                                               | Preset Options                                                    | Shows the maximum number of index keys.                                                                                                 | internal          | f', ' segment_size                           | 131072                                                           | Preset Options                                                    | Shows the number of pages per disk file.                                                                                                | internal          | f', ' server_version                         | 13.5                                                             | Preset Options                                                    | Shows the server version.                                                                                                               | internal          | f', ' server_version_num                     | 130005                                                           | Preset Options                                                    | Shows the server version as an integer.                                                                                                 | internal          | f', ' ssl_library                            | OpenSSL                                                          | Preset Options                                                    | Name of the SSL library.                                                                                                                | internal          | f', ' wal_block_size                         | 8192                                                             | Preset Options                                                    | Shows the block size in the write ahead log.                                                                                            | internal          | f', ' wal_segment_size                       | 16777216                                                         | Preset Options                                                    | Shows the size of write ahead log segments.                                                                                             | internal          | f', ' cluster_name                           |                                                                  | Process Title                                                     | Sets the name of the cluster, which is included in the process title.                                                                   | postmaster        | f', ' update_process_title                   | on                                                               | Process Title                                                     | Updates the process title to show the active SQL command.                                                                               | superuser         | f', ' geqo                                   | on                                                               | Query Tuning / Genetic Query Optimizer                            | Enables genetic query optimization.                                                                                                     | user              | f', ' geqo_effort                            | 5                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: effort is used to set the default for other GEQO parameters.                                                                      | user              | f', ' geqo_generations                       | 0                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: number of iterations of the algorithm.                                                                                            | user              | f', ' geqo_pool_size                         | 0                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: number of individuals in the population.                                                                                          | user              | f', ' geqo_seed                              | 0                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: seed for random path selection.                                                                                                   | user              | f', ' geqo_selection_bias                    | 2                                                                | Query Tuning / Genetic Query Optimizer                            | GEQO: selective pressure within the population.                                                                                         | user              | f', ' geqo_threshold                         | 12                                                               | Query Tuning / Genetic Query Optimizer                            | Sets the threshold of FROM items beyond which GEQO is used.                                                                             | user              | f', ' constraint_exclusion                   | partition                                                        | Query Tuning / Other Planner Options                              | Enables the planner to use constraints to optimize queries.                                                                             | user              | f', " cursor_tuple_fraction                  | 0.1                                                              | Query Tuning / Other Planner Options                              | Sets the planner's estimate of the fraction of a cursor's rows that will be retrieved.                                                  | user              | f", ' default_statistics_target              | 100                                                              | Query Tuning / Other Planner Options                              | Sets the default statistics target.                                                                                                     | user              | f', ' force_parallel_mode                    | off                                                              | Query Tuning / Other Planner Options                              | Forces use of parallel query facilities.                                                                                                | user              | f', ' from_collapse_limit                    | 8                                                                | Query Tuning / Other Planner Options                              | Sets the FROM-list size beyond which subqueries are not collapsed.                                                                      | user              | f', ' jit                                    | on                                                               | Query Tuning / Other Planner Options                              | Allow JIT compilation.                                                                                                                  | user              | f', ' join_collapse_limit                    | 8                                                                | Query Tuning / Other Planner Options                              | Sets the FROM-list size beyond which JOIN constructs are not flattened.                                                                 | user              | f', " plan_cache_mode                        | auto                                                             | Query Tuning / Other Planner Options                              | Controls the planner's selection of custom or generic plan.                                                                             | user              | f", " cpu_index_tuple_cost                   | 0.005                                                            | Query Tuning / Planner Cost Constants                             | Sets the planner's estimate of the cost of processing each index entry during an index scan.                                            | user              | f", " cpu_operator_cost                      | 0.0025                                                           | Query Tuning / Planner Cost Constants                             | Sets the planner's estimate of the cost of processing each operator or function call.                                                   | user              | f", " cpu_tuple_cost                         | 0.01                                                             | Query Tuning / Planner Cost Constants                             | Sets the planner's estimate of the cost of processing each tuple (row).                                                                 | user              | f", " effective_cache_size                   | 524288                                                           | Query Tuning / Planner Cost Constants                             | Sets the planner's assumption about the total size of the data caches.                                                                  | user              | f", ' jit_above_cost                         | 100000                                                           | Query Tuning / Planner Cost Constants                             | Perform JIT compilation if query is more expensive.                                                                                     | user              | f', ' jit_inline_above_cost                  | 500000                                                           | Query Tuning / Planner Cost Constants                             | Perform JIT inlining if query is more expensive.                                                                                        | user              | f', ' jit_optimize_above_cost                | 500000                                                           | Query Tuning / Planner Cost Constants                             | Optimize JITed functions if query is more expensive.                                                                                    | user              | f', ' min_parallel_index_scan_size           | 64                                                               | Query Tuning / Planner Cost Constants                             | Sets the minimum amount of index data for a parallel scan.                                                                              | user              | f', ' min_parallel_table_scan_size           | 1024                                                             | Query Tuning / Planner Cost Constants                             | Sets the minimum amount of table data for a parallel scan.                                                                              | user              | f', " parallel_setup_cost                    | 1000                                                             | Query Tuning / Planner Cost Constants                             | Sets the planner's estimate of the cost of starting up worker processes for parallel query.                                             | user              | f", " parallel_tuple_cost                    | 0.1                                                              | Query Tuning / Planner Cost Constants                             | Sets the planner's estimate of the cost of passing each tuple (row) from worker to master backend.                                      | user              | f", " random_page_cost                       | 4                                                                | Query Tuning / Planner Cost Constants                             | Sets the planner's estimate of the cost of a nonsequentially fetched disk page.                                                         | user              | f", " seq_page_cost                          | 1                                                                | Query Tuning / Planner Cost Constants                             | Sets the planner's estimate of the cost of a sequentially fetched disk page.                                                            | user              | f", " enable_bitmapscan                      | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of bitmap-scan plans.                                                                                         | user              | f", " enable_gathermerge                     | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of gather merge plans.                                                                                        | user              | f", " enable_hashagg                         | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of hashed aggregation plans.                                                                                  | user              | f", " enable_hashjoin                        | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of hash join plans.                                                                                           | user              | f", " enable_incremental_sort                | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of incremental sort steps.                                                                                    | user              | f", " enable_indexonlyscan                   | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of index-only-scan plans.                                                                                     | user              | f", " enable_indexscan                       | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of index-scan plans.                                                                                          | user              | f", " enable_material                        | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of materialization.                                                                                           | user              | f", " enable_mergejoin                       | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of merge join plans.                                                                                          | user              | f", " enable_nestloop                        | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of nested-loop join plans.                                                                                    | user              | f", " enable_parallel_append                 | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of parallel append plans.                                                                                     | user              | f", " enable_parallel_hash                   | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of parallel hash plans.                                                                                       | user              | f", ' enable_partition_pruning               | on                                                               | Query Tuning / Planner Method Configuration                       | Enables plan-time and run-time partition pruning.                                                                                       | user              | f', ' enable_partitionwise_aggregate         | off                                                              | Query Tuning / Planner Method Configuration                       | Enables partitionwise aggregation and grouping.                                                                                         | user              | f', ' enable_partitionwise_join              | off                                                              | Query Tuning / Planner Method Configuration                       | Enables partitionwise join.                                                                                                             | user              | f', " enable_seqscan                         | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of sequential-scan plans.                                                                                     | user              | f", " enable_sort                            | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of explicit sort steps.                                                                                       | user              | f", " enable_tidscan                         | on                                                               | Query Tuning / Planner Method Configuration                       | Enables the planner's use of TID scan plans.                                                                                            | user              | f", ' track_commit_timestamp                 | off                                                              | Replication                                                       | Collects transaction commit time.                                                                                                       | postmaster        | f', ' synchronous_standby_names              | standby                                                          | Replication / Master Server                                       | Number of synchronous standbys and list of names of potential synchronous ones.                                                         | sighup            | f', ' vacuum_defer_cleanup_age               | 0                                                                | Replication / Master Server                                       | Number of transactions by which VACUUM and HOT cleanup should be deferred, if any.                                                      | sighup            | f', ' max_replication_slots                  | 10                                                               | Replication / Sending Servers                                     | Sets the maximum number of simultaneously defined replication slots.                                                                    | postmaster        | f', ' max_slot_wal_keep_size                 | -1                                                               | Replication / Sending Servers                                     | Sets the maximum WAL size that can be reserved by replication slots.                                                                    | sighup            | f', ' max_wal_senders                        | 2                                                                | Replication / Sending Servers                                     | Sets the maximum number of simultaneously running WAL sender processes.                                                                 | postmaster        | f', ' wal_keep_size                          | 0                                                                | Replication / Sending Servers                                     | Sets the size of WAL files held for standby servers.                                                                                    | sighup            | f', ' wal_sender_timeout                     | 60000                                                            | Replication / Sending Servers                                     | Sets the maximum time to wait for WAL replication.                                                                                      | user              | f', ' hot_standby                            | on                                                               | Replication / Standby Servers                                     | Allows connections and queries during recovery.                                                                                         | postmaster        | f', ' hot_standby_feedback                   | off                                                              | Replication / Standby Servers                                     | Allows feedback from a hot standby to the primary that will avoid query conflicts.                                                      | sighup            | f', ' max_standby_archive_delay              | 30000                                                            | Replication / Standby Servers                                     | Sets the maximum delay before canceling queries when a hot standby server is processing archived WAL data.                              | sighup            | f', ' max_standby_streaming_delay            | 30000                                                            | Replication / Standby Servers                                     | Sets the maximum delay before canceling queries when a hot standby server is processing streamed WAL data.                              | sighup            | f', ' primary_conninfo                       | host=192.168.40.10 port=5432 user=replicator password=replicator | Replication / Standby Servers                                     | Sets the connection string to be used to connect to the sending server.                                                                 | sighup            | f', ' primary_slot_name                      | pg_slot_replication                                              | Replication / Standby Servers                                     | Sets the name of the replication slot to use on the sending server.                                                                     | sighup            | f', ' promote_trigger_file                   | /tmp/trigger.192.168.40.10.5432                                  | Replication / Standby Servers                                     | Specifies a file name whose presence ends recovery in the standby.                                                                      | sighup            | f', ' recovery_min_apply_delay               | 0                                                                | Replication / Standby Servers                                     | Sets the minimum delay for applying changes during recovery.                                                                            | sighup            | f', ' wal_receiver_create_temp_slot          | off                                                              | Replication / Standby Servers                                     | Sets whether a WAL receiver should create a temporary replication slot if no permanent slot is configured.                              | sighup            | f', ' wal_receiver_status_interval           | 10                                                               | Replication / Standby Servers                                     | Sets the maximum interval between WAL receiver status reports to the sending server.                                                    | sighup            | f', ' wal_receiver_timeout                   | 60000                                                            | Replication / Standby Servers                                     | Sets the maximum wait time to receive data from the sending server.                                                                     | sighup            | f', ' wal_retrieve_retry_interval            | 5000                                                             | Replication / Standby Servers                                     | Sets the time to wait before retrying to retrieve WAL after a failed attempt.                                                           | sighup            | f', ' max_logical_replication_workers        | 4                                                                | Replication / Subscribers                                         | Maximum number of logical replication worker processes.                                                                                 | postmaster        | f', ' max_sync_workers_per_subscription      | 2                                                                | Replication / Subscribers                                         | Maximum number of table synchronization workers per subscription.                                                                       | sighup            | f', ' application_name                       | psql                                                             | Reporting and Logging / What to Log                               | Sets the application name to be reported in statistics and logs.                                                                        | user              | f', ' debug_pretty_print                     | on                                                               | Reporting and Logging / What to Log                               | Indents parse and plan tree displays.                                                                                                   | user              | f', " debug_print_parse                      | off                                                              | Reporting and Logging / What to Log                               | Logs each query's parse tree.                                                                                                           | user              | f", " debug_print_plan                       | off                                                              | Reporting and Logging / What to Log                               | Logs each query's execution plan.                                                                                                       | user              | f", " debug_print_rewritten                  | off                                                              | Reporting and Logging / What to Log                               | Logs each query's rewritten parse tree.                                                                                                 | user              | f", ' log_autovacuum_min_duration            | -1                                                               | Reporting and Logging / What to Log                               | Sets the minimum execution time above which autovacuum actions will be logged.                                                          | sighup            | f', ' log_checkpoints                        | off                                                              | Reporting and Logging / What to Log                               | Logs each checkpoint.                                                                                                                   | sighup            | f', ' log_connections                        | off                                                              | Reporting and Logging / What to Log                               | Logs each successful connection.                                                                                                        | superuser-backend | f', ' log_disconnections                     | off                                                              | Reporting and Logging / What to Log                               | Logs end of a session, including duration.                                                                                              | superuser-backend | f', ' log_duration                           | off                                                              | Reporting and Logging / What to Log                               | Logs the duration of each completed SQL statement.                                                                                      | superuser         | f', ' log_error_verbosity                    | default                                                          | Reporting and Logging / What to Log                               | Sets the verbosity of logged messages.                                                                                                  | superuser         | f', ' log_hostname                           | off                                                              | Reporting and Logging / What to Log                               | Logs the host name in the connection logs.                                                                                              | sighup            | f', ' log_line_prefix                        | %m [%p]                                                          | Reporting and Logging / What to Log                               | Controls information prefixed to each log line.                                                                                         | sighup            | f', ' log_lock_waits                         | off                                                              | Reporting and Logging / What to Log                               | Logs long lock waits.                                                                                                                   | superuser         | f', ' log_parameter_max_length               | -1                                                               | Reporting and Logging / What to Log                               | When logging statements, limit logged parameter values to first N bytes.                                                                | superuser         | f', ' log_parameter_max_length_on_error      | 0                                                                | Reporting and Logging / What to Log                               | When reporting an error, limit logged parameter values to first N bytes.                                                                | user              | f', ' log_replication_commands               | off                                                              | Reporting and Logging / What to Log                               | Logs each replication command.                                                                                                          | superuser         | f', ' log_statement                          | none                                                             | Reporting and Logging / What to Log                               | Sets the type of statements logged.                                                                                                     | superuser         | f', ' log_temp_files                         | -1                                                               | Reporting and Logging / What to Log                               | Log the use of temporary files larger than this number of kilobytes.                                                                    | superuser         | f', ' log_timezone                           | UTC                                                              | Reporting and Logging / What to Log                               | Sets the time zone to use in log messages.                                                                                              | sighup            | f', ' log_min_duration_sample                | -1                                                               | Reporting and Logging / When to Log                               | Sets the minimum execution time above which a sample of statements will be logged. Sampling is determined by log_statement_sample_rate. | superuser         | f', ' log_min_duration_statement             | -1                                                               | Reporting and Logging / When to Log                               | Sets the minimum execution time above which all statements will be logged.                                                              | superuser         | f', ' log_min_error_statement                | error                                                            | Reporting and Logging / When to Log                               | Causes all statements generating error at or above this level to be logged.                                                             | superuser         | f', ' log_min_messages                       | warning                                                          | Reporting and Logging / When to Log                               | Sets the message levels that are logged.                                                                                                | superuser         | f', ' log_statement_sample_rate              | 1                                                                | Reporting and Logging / When to Log                               | Fraction of statements exceeding log_min_duration_sample to be logged.                                                                  | superuser         | f', ' log_transaction_sample_rate            | 0                                                                | Reporting and Logging / When to Log                               | Set the fraction of transactions to log for new transactions.                                                                           | superuser         | f', ' event_source                           | PostgreSQL                                                       | Reporting and Logging / Where to Log                              | Sets the application name used to identify PostgreSQL messages in the event log.                                                        | postmaster        | f', ' log_destination                        | stderr                                                           | Reporting and Logging / Where to Log                              | Sets the destination for server log output.                                                                                             | sighup            | f', ' log_directory                          | log                                                              | Reporting and Logging / Where to Log                              | Sets the destination directory for log files.                                                                                           | sighup            | f', ' log_file_mode                          | 0600                                                             | Reporting and Logging / Where to Log                              | Sets the file permissions for log files.                                                                                                | sighup            | f', ' log_filename                           | postgresql-%a.log                                                | Reporting and Logging / Where to Log                              | Sets the file name pattern for log files.                                                                                               | sighup            | f', ' logging_collector                      | on                                                               | Reporting and Logging / Where to Log                              | Start a subprocess to capture stderr output and/or csvlogs into log files.                                                              | postmaster        | f', ' log_rotation_age                       | 1440                                                             | Reporting and Logging / Where to Log                              | Automatic log file rotation will occur after N minutes.                                                                                 | sighup            | f', ' log_rotation_size                      | 0                                                                | Reporting and Logging / Where to Log                              | Automatic log file rotation will occur after N kilobytes.                                                                               | sighup            | f', ' log_truncate_on_rotation               | on                                                               | Reporting and Logging / Where to Log                              | Truncate existing log files of same name during log rotation.                                                                           | sighup            | f', ' syslog_facility                        | local0                                                           | Reporting and Logging / Where to Log                              | Sets the syslog "facility" to be used when syslog enabled.                                                                              | sighup            | f', ' syslog_ident                           | postgres                                                         | Reporting and Logging / Where to Log                              | Sets the program name used to identify PostgreSQL messages in syslog.                                                                   | sighup            | f', ' syslog_sequence_numbers                | on                                                               | Reporting and Logging / Where to Log                              | Add sequence number to syslog messages to avoid duplicate suppression.                                                                  | sighup            | f', ' syslog_split_messages                  | on                                                               | Reporting and Logging / Where to Log                              | Split messages sent to syslog by lines and to fit into 1024 bytes.                                                                      | sighup            | f', ' backend_flush_after                    | 0                                                                | Resource Usage / Asynchronous Behavior                            | Number of pages after which previously performed writes are flushed to disk.                                                            | user              | f', ' effective_io_concurrency               | 1                                                                | Resource Usage / Asynchronous Behavior                            | Number of simultaneous requests that can be handled efficiently by the disk subsystem.                                                  | user              | f', ' maintenance_io_concurrency             | 10                                                               | Resource Usage / Asynchronous Behavior                            | A variant of effective_io_concurrency that is used for maintenance work.                                                                | user              | f', ' max_parallel_maintenance_workers       | 2                                                                | Resource Usage / Asynchronous Behavior                            | Sets the maximum number of parallel processes per maintenance operation.                                                                | user              | f', ' max_parallel_workers                   | 8                                                                | Resource Usage / Asynchronous Behavior                            | Sets the maximum number of parallel workers that can be active at one time.                                                             | user              | f', ' max_parallel_workers_per_gather        | 2                                                                | Resource Usage / Asynchronous Behavior                            | Sets the maximum number of parallel processes per executor node.                                                                        | user              | f', ' max_worker_processes                   | 8                                                                | Resource Usage / Asynchronous Behavior                            | Maximum number of concurrent worker processes.                                                                                          | postmaster        | f', ' old_snapshot_threshold                 | -1                                                               | Resource Usage / Asynchronous Behavior                            | Time before a snapshot is too old to read pages changed after the snapshot was taken.                                                   | postmaster        | f', ' parallel_leader_participation          | on                                                               | Resource Usage / Asynchronous Behavior                            | Controls whether Gather and Gather Merge also run subplans.                                                                             | user              | f', ' bgwriter_delay                         | 200                                                              | Resource Usage / Background Writer                                | Background writer sleep time between rounds.                                                                                            | sighup            | f', ' bgwriter_flush_after                   | 64                                                               | Resource Usage / Background Writer                                | Number of pages after which previously performed writes are flushed to disk.                                                            | sighup            | f', ' bgwriter_lru_maxpages                  | 100                                                              | Resource Usage / Background Writer                                | Background writer maximum number of LRU pages to flush per round.                                                                       | sighup            | f', ' bgwriter_lru_multiplier                | 2                                                                | Resource Usage / Background Writer                                | Multiple of the average buffer usage to free per round.                                                                                 | sighup            | f', ' vacuum_cost_delay                      | 0                                                                | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost delay in milliseconds.                                                                                                      | user              | f', ' vacuum_cost_limit                      | 200                                                              | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost amount available before napping.                                                                                            | user              | f', ' vacuum_cost_page_dirty                 | 20                                                               | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost for a page dirtied by vacuum.                                                                                               | user              | f', ' vacuum_cost_page_hit                   | 1                                                                | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost for a page found in the buffer cache.                                                                                       | user              | f', ' vacuum_cost_page_miss                  | 10                                                               | Resource Usage / Cost-Based Vacuum Delay                          | Vacuum cost for a page not found in the buffer cache.                                                                                   | user              | f', ' temp_file_limit                        | -1                                                               | Resource Usage / Disk                                             | Limits the total size of all temporary files used by each process.                                                                      | superuser         | f', ' max_files_per_process                  | 1000                                                             | Resource Usage / Kernel Resources                                 | Sets the maximum number of simultaneously open files for each server process.                                                           | postmaster        | f', ' autovacuum_work_mem                    | -1                                                               | Resource Usage / Memory                                           | Sets the maximum memory to be used by each autovacuum worker process.                                                                   | sighup            | f', ' dynamic_shared_memory_type             | posix                                                            | Resource Usage / Memory                                           | Selects the dynamic shared memory implementation used.                                                                                  | postmaster        | f', ' hash_mem_multiplier                    | 1                                                                | Resource Usage / Memory                                           | Multiple of work_mem to use for hash tables.                                                                                            | user              | f', ' huge_pages                             | try                                                              | Resource Usage / Memory                                           | Use of huge pages on Linux or Windows.                                                                                                  | postmaster        | f', ' logical_decoding_work_mem              | 65536                                                            | Resource Usage / Memory                                           | Sets the maximum memory to be used for logical decoding.                                                                                | user              | f', ' maintenance_work_mem                   | 65536                                                            | Resource Usage / Memory                                           | Sets the maximum memory to be used for maintenance operations.                                                                          | user              | f', ' max_prepared_transactions              | 0                                                                | Resource Usage / Memory                                           | Sets the maximum number of simultaneously prepared transactions.                                                                        | postmaster        | f', ' max_stack_depth                        | 2048                                                             | Resource Usage / Memory                                           | Sets the maximum stack depth, in kilobytes.                                                                                             | superuser         | f', ' shared_buffers                         | 16384                                                            | Resource Usage / Memory                                           | Sets the number of shared memory buffers used by the server.                                                                            | postmaster        | f', ' shared_memory_type                     | mmap                                                             | Resource Usage / Memory                                           | Selects the shared memory implementation used for the main shared memory region.                                                        | postmaster        | f', ' temp_buffers                           | 1024                                                             | Resource Usage / Memory                                           | Sets the maximum number of temporary buffers used by each session.                                                                      | user              | f', ' track_activity_query_size              | 1024                                                             | Resource Usage / Memory                                           | Sets the size reserved for pg_stat_activity.query, in bytes.                                                                            | postmaster        | f', ' work_mem                               | 4096                                                             | Resource Usage / Memory                                           | Sets the maximum memory to be used for query workspaces.                                                                                | user              | f', ' log_executor_stats                     | off                                                              | Statistics / Monitoring                                           | Writes executor performance statistics to the server log.                                                                               | superuser         | f', ' log_parser_stats                       | off                                                              | Statistics / Monitoring                                           | Writes parser performance statistics to the server log.                                                                                 | superuser         | f', ' log_planner_stats                      | off                                                              | Statistics / Monitoring                                           | Writes planner performance statistics to the server log.                                                                                | superuser         | f', ' log_statement_stats                    | off                                                              | Statistics / Monitoring                                           | Writes cumulative performance statistics to the server log.                                                                             | superuser         | f', ' stats_temp_directory                   | pg_stat_tmp                                                      | Statistics / Query and Index Statistics Collector                 | Writes temporary statistics files to the specified directory.                                                                           | sighup            | f', ' track_activities                       | on                                                               | Statistics / Query and Index Statistics Collector                 | Collects information about executing commands.                                                                                          | superuser         | f', ' track_counts                           | on                                                               | Statistics / Query and Index Statistics Collector                 | Collects statistics on database activity.                                                                                               | superuser         | f', ' track_functions                        | none                                                             | Statistics / Query and Index Statistics Collector                 | Collects function-level statistics on database activity.                                                                                | superuser         | f', ' track_io_timing                        | off                                                              | Statistics / Query and Index Statistics Collector                 | Collects timing statistics for database I/O activity.                                                                                   | superuser         | f', ' transform_null_equals                  | off                                                              | Version and Platform Compatibility / Other Platforms and Clients  | Treats "expr=NULL" as "expr IS NULL".                                                                                                   | user              | f', ' array_nulls                            | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Enable input of NULL elements in arrays.                                                                                                | user              | f', ' backslash_quote                        | safe_encoding                                                    | Version and Platform Compatibility / Previous PostgreSQL Versions | Sets whether "\\\'" is allowed in string literals.                                                                                        | user              | f', ' escape_string_warning                  | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Warn about backslash escapes in ordinary string literals.                                                                               | user              | f', ' lo_compat_privileges                   | off                                                              | Version and Platform Compatibility / Previous PostgreSQL Versions | Enables backward compatibility mode for privilege checks on large objects.                                                              | superuser         | f', ' operator_precedence_warning            | off                                                              | Version and Platform Compatibility / Previous PostgreSQL Versions | Emit a warning for constructs that changed meaning since PostgreSQL 9.4.                                                                | user              | f', ' quote_all_identifiers                  | off                                                              | Version and Platform Compatibility / Previous PostgreSQL Versions | When generating SQL fragments, quote all identifiers.                                                                                   | user              | f', " standard_conforming_strings            | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Causes '...' strings to treat backslashes literally.                                                                                    | user              | f", ' synchronize_seqscans                   | on                                                               | Version and Platform Compatibility / Previous PostgreSQL Versions | Enable synchronized sequential scans.                                                                                                   | user              | f', ' archive_cleanup_command                |                                                                  | Write-Ahead Log / Archive Recovery                                | Sets the shell command that will be executed at every restart point.                                                                    | sighup            | f', ' recovery_end_command                   |                                                                  | Write-Ahead Log / Archive Recovery                                | Sets the shell command that will be executed once at the end of recovery.                                                               | sighup            | f', ' restore_command                        |                                                                  | Write-Ahead Log / Archive Recovery                                | Sets the shell command that will be called to retrieve an archived WAL file.                                                            | postmaster        | f', ' archive_command                        |                                                                  | Write-Ahead Log / Archiving                                       | Sets the shell command that will be called to archive a WAL file.                                                                       | sighup            | f', ' archive_mode                           | on                                                               | Write-Ahead Log / Archiving                                       | Allows archiving of WAL files using archive_command.                                                                                    | postmaster        | f', ' archive_timeout                        | 0                                                                | Write-Ahead Log / Archiving                                       | Forces a switch to the next WAL file if a new file has not been started within N seconds.                                               | sighup            | f', ' checkpoint_completion_target           | 0.5                                                              | Write-Ahead Log / Checkpoints                                     | Time spent flushing dirty buffers during checkpoint, as fraction of checkpoint interval.                                                | sighup            | f', ' checkpoint_flush_after                 | 32                                                               | Write-Ahead Log / Checkpoints                                     | Number of pages after which previously performed writes are flushed to disk.                                                            | sighup            | f', ' checkpoint_timeout                     | 300                                                              | Write-Ahead Log / Checkpoints                                     | Sets the maximum time between automatic WAL checkpoints.                                                                                | sighup            | f', ' checkpoint_warning                     | 30                                                               | Write-Ahead Log / Checkpoints                                     | Enables warnings if checkpoint segments are filled more frequently than this.                                                           | sighup            | f', ' max_wal_size                           | 1024                                                             | Write-Ahead Log / Checkpoints                                     | Sets the WAL size that triggers a checkpoint.                                                                                           | sighup            | f', ' min_wal_size                           | 80                                                               | Write-Ahead Log / Checkpoints                                     | Sets the minimum size to shrink the WAL to.                                                                                             | sighup            | f', ' recovery_target                        |                                                                  | Write-Ahead Log / Recovery Target                                 | Set to "immediate" to end recovery as soon as a consistent state is reached.                                                            | postmaster        | f', ' recovery_target_action                 | pause                                                            | Write-Ahead Log / Recovery Target                                 | Sets the action to perform upon reaching the recovery target.                                                                           | postmaster        | f', ' recovery_target_inclusive              | on                                                               | Write-Ahead Log / Recovery Target                                 | Sets whether to include or exclude transaction with recovery target.                                                                    | postmaster        | f', ' recovery_target_lsn                    |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the LSN of the write-ahead log location up to which recovery will proceed.                                                         | postmaster        | f', ' recovery_target_name                   |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the named restore point up to which recovery will proceed.                                                                         | postmaster        | f', ' recovery_target_time                   |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the time stamp up to which recovery will proceed.                                                                                  | postmaster        | f', ' recovery_target_timeline               | latest                                                           | Write-Ahead Log / Recovery Target                                 | Specifies the timeline to recover into.                                                                                                 | postmaster        | f', ' recovery_target_xid                    |                                                                  | Write-Ahead Log / Recovery Target                                 | Sets the transaction ID up to which recovery will proceed.                                                                              | postmaster        | f', ' commit_delay                           | 0                                                                | Write-Ahead Log / Settings                                        | Sets the delay in microseconds between transaction commit and flushing WAL to disk.                                                     | superuser         | f', ' commit_siblings                        | 5                                                                | Write-Ahead Log / Settings                                        | Sets the minimum concurrent open transactions before performing commit_delay.                                                           | user              | f', ' fsync                                  | on                                                               | Write-Ahead Log / Settings                                        | Forces synchronization of updates to disk.                                                                                              | sighup            | f', ' full_page_writes                       | on                                                               | Write-Ahead Log / Settings                                        | Writes full pages to WAL when first modified after a checkpoint.                                                                        | sighup            | f', " synchronous_commit                     | local                                                            | Write-Ahead Log / Settings                                        | Sets the current transaction's synchronization level.                                                                                   | user              | f", ' wal_buffers                            | 512                                                              | Write-Ahead Log / Settings                                        | Sets the number of disk-page buffers in shared memory for WAL.                                                                          | postmaster        | f', ' wal_compression                        | off                                                              | Write-Ahead Log / Settings                                        | Compresses full-page writes written in WAL file.                                                                                        | superuser         | f', ' wal_init_zero                          | on                                                               | Write-Ahead Log / Settings                                        | Writes zeroes to new WAL files before first use.                                                                                        | superuser         | f', ' wal_level                              | replica                                                          | Write-Ahead Log / Settings                                        | Set the level of information written to the WAL.                                                                                        | postmaster        | f', ' wal_log_hints                          | off                                                              | Write-Ahead Log / Settings                                        | Writes full pages to WAL when first modified after a checkpoint, even for a non-critical modification.                                  | postmaster        | f', ' wal_recycle                            | on                                                               | Write-Ahead Log / Settings                                        | Recycles WAL files by renaming them.                                                                                                    | superuser         | f', ' wal_skip_threshold                     | 2048                                                             | Write-Ahead Log / Settings                                        | Size of new file to fsync instead of writing WAL.                                                                                       | user              | f', ' wal_sync_method                        | fdatasync                                                        | Write-Ahead Log / Settings                                        | Selects the method used for forcing WAL updates to disk.                                                                                | sighup            | f', ' wal_writer_delay                       | 200                                                              | Write-Ahead Log / Settings                                        | Time between WAL flushes performed in the WAL writer.                                                                                   | sighup            | f', ' wal_writer_flush_after                 | 128                                                              | Write-Ahead Log / Settings                                        | Amount of WAL written out by WAL writer that triggers a flush.                                                                          | sighup            | f', '(329 строк)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT name, setting, category, short_desc, context, pending_restart FROM pg_catalog.pg_settings ORDER BY category, name;', 'ansible_loop_var': 'item'})

PLAY RECAP *********************************************************************
replica                    : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

Полученные результаты:


<details><summary>см. результат `SELECT datname AS databases FROM pg_database`</summary>

```text
-- SELECT datname AS database_name FROM pg_database;
 database_name 
---------------
 postgres
 template1
 template0
(3 строки)
```

</details>

<details><summary>см. результат `SELECT schema_name FROM information_schema.schemata`</summary>

```text
-- SELECT schema_name FROM information_schema.schemata;
    schema_name     
--------------------
 pg_toast
 pg_catalog
 public
 information_schema
(4 строки)
```

</details>

<details><summary>см. результат `SELECT schemaname, tablename FROM pg_catalog.pg_tables`</summary>

```text
-- SELECT schemaname, tablename FROM pg_catalog.pg_tables;
     schemaname     |        tablename        
--------------------+-------------------------
 pg_catalog         | pg_statistic
 pg_catalog         | pg_type
 pg_catalog         | pg_foreign_table
 pg_catalog         | pg_authid
 pg_catalog         | pg_statistic_ext_data
 pg_catalog         | pg_largeobject
 pg_catalog         | pg_user_mapping
 pg_catalog         | pg_subscription
 pg_catalog         | pg_attribute
 pg_catalog         | pg_proc
 pg_catalog         | pg_class
 pg_catalog         | pg_attrdef
 pg_catalog         | pg_constraint
 pg_catalog         | pg_inherits
 pg_catalog         | pg_index
 pg_catalog         | pg_operator
 pg_catalog         | pg_opfamily
 pg_catalog         | pg_opclass
 pg_catalog         | pg_am
 pg_catalog         | pg_amop
 pg_catalog         | pg_amproc
 pg_catalog         | pg_language
 pg_catalog         | pg_largeobject_metadata
 pg_catalog         | pg_aggregate
 pg_catalog         | pg_statistic_ext
 pg_catalog         | pg_rewrite
 pg_catalog         | pg_trigger
 pg_catalog         | pg_event_trigger
 pg_catalog         | pg_description
 pg_catalog         | pg_cast
 pg_catalog         | pg_enum
 pg_catalog         | pg_namespace
 pg_catalog         | pg_conversion
 pg_catalog         | pg_depend
 pg_catalog         | pg_database
 pg_catalog         | pg_db_role_setting
 pg_catalog         | pg_tablespace
 pg_catalog         | pg_auth_members
 pg_catalog         | pg_shdepend
 pg_catalog         | pg_shdescription
 pg_catalog         | pg_ts_config
 pg_catalog         | pg_ts_config_map
 pg_catalog         | pg_ts_dict
 pg_catalog         | pg_ts_parser
 pg_catalog         | pg_ts_template
 pg_catalog         | pg_extension
 pg_catalog         | pg_foreign_data_wrapper
 pg_catalog         | pg_foreign_server
 pg_catalog         | pg_policy
 pg_catalog         | pg_replication_origin
 pg_catalog         | pg_default_acl
 pg_catalog         | pg_init_privs
 pg_catalog         | pg_seclabel
 pg_catalog         | pg_shseclabel
 pg_catalog         | pg_collation
 pg_catalog         | pg_partitioned_table
 pg_catalog         | pg_range
 pg_catalog         | pg_transform
 pg_catalog         | pg_sequence
 pg_catalog         | pg_publication
 pg_catalog         | pg_publication_rel
 pg_catalog         | pg_subscription_rel
 information_schema | sql_implementation_info
 information_schema | sql_parts
 information_schema | sql_sizing
 information_schema | sql_features
(66 строк)
```

</details>

##### Что есть на мастере и совершаем CRUD-"действия"

```shell
ansible-playbook playbooks/master_check_and_activity.yml > ../files/004_playbooks-master_check_and_activity.yml.txt
```


<details><summary>см. лог выполнения `playbooks/master_check_and_activity.yml`</summary>

```text

PLAY [Playbook of check master] ************************************************

TASK [Gathering Facts] *********************************************************
ok: [master]

TASK [../roles/master_check_and_activity : PostgreSQL master checker] **********
changed: [master] => (item=SELECT application_name, state, sync_priority, sync_state FROM pg_stat_replication;)
changed: [master] => (item=SELECT * FROM pg_stat_replication;)
changed: [master] => (item=SELECT datname AS database_name FROM pg_database;)
changed: [master] => (item=SELECT schema_name FROM information_schema.schemata;)
changed: [master] => (item=SELECT schemaname, tablename FROM pg_catalog.pg_tables;)
changed: [master] => (item=SHOW archive_mode;)
changed: [master] => (item=SHOW archive_command;)

TASK [../roles/master_check_and_activity : Store check to file] ****************
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:56.178833', 'stdout': ' application_name |   state   | sync_priority | sync_state \n------------------+-----------+---------------+------------\n walreceiver      | streaming |             0 | async\n(1 строка)', 'cmd': 'sudo -iu postgres psql -c "SELECT application_name, state, sync_priority, sync_state FROM pg_stat_replication;"', 'rc': 0, 'start': '2025-02-19 17:49:55.710762', 'stderr': '', 'delta': '0:00:00.468071', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT application_name, state, sync_priority, sync_state FROM pg_stat_replication;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': [' application_name |   state   | sync_priority | sync_state ', '------------------+-----------+---------------+------------', ' walreceiver      | streaming |             0 | async', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT application_name, state, sync_priority, sync_state FROM pg_stat_replication;', 'ansible_loop_var': 'item'})
changed: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:56.822286', 'stdout': '  pid  | usesysid |  usename   | application_name |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn |    write_lag    |   flush_lag    |   replay_lag    | sync_priority | sync_state |          reply_time           \n-------+----------+------------+------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------------+----------------+-----------------+---------------+------------+-------------------------------\n 29243 |    16384 | replicator | walreceiver      | 192.168.40.11 |                 |       36038 | 2025-02-19 17:49:41.469113+00 |              | streaming | 0/3000060 | 0/3000060 | 0/3000060 | 0/3000060  | 00:00:00.079097 | 00:00:00.08052 | 00:00:00.080527 |             0 | async      | 2025-02-19 17:49:55.318138+00\n(1 строка)', 'cmd': 'sudo -iu postgres psql -c "SELECT * FROM pg_stat_replication;"', 'rc': 0, 'start': '2025-02-19 17:49:56.695559', 'stderr': '', 'delta': '0:00:00.126727', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT * FROM pg_stat_replication;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['  pid  | usesysid |  usename   | application_name |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn |    write_lag    |   flush_lag    |   replay_lag    | sync_priority | sync_state |          reply_time           ', '-------+----------+------------+------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------------+----------------+-----------------+---------------+------------+-------------------------------', ' 29243 |    16384 | replicator | walreceiver      | 192.168.40.11 |                 |       36038 | 2025-02-19 17:49:41.469113+00 |              | streaming | 0/3000060 | 0/3000060 | 0/3000060 | 0/3000060  | 00:00:00.079097 | 00:00:00.08052 | 00:00:00.080527 |             0 | async      | 2025-02-19 17:49:55.318138+00', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT * FROM pg_stat_replication;', 'ansible_loop_var': 'item'})
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:57.451457', 'stdout': ' database_name \n---------------\n postgres\n template1\n template0\n(3 строки)', 'cmd': 'sudo -iu postgres psql -c "SELECT datname AS database_name FROM pg_database;"', 'rc': 0, 'start': '2025-02-19 17:49:57.332144', 'stderr': '', 'delta': '0:00:00.119313', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT datname AS database_name FROM pg_database;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': [' database_name ', '---------------', ' postgres', ' template1', ' template0', '(3 строки)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT datname AS database_name FROM pg_database;', 'ansible_loop_var': 'item'})
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:58.077622', 'stdout': '    schema_name     \n--------------------\n pg_toast\n pg_catalog\n public\n information_schema\n(4 строки)', 'cmd': 'sudo -iu postgres psql -c "SELECT schema_name FROM information_schema.schemata;"', 'rc': 0, 'start': '2025-02-19 17:49:57.956800', 'stderr': '', 'delta': '0:00:00.120822', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT schema_name FROM information_schema.schemata;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['    schema_name     ', '--------------------', ' pg_toast', ' pg_catalog', ' public', ' information_schema', '(4 строки)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT schema_name FROM information_schema.schemata;', 'ansible_loop_var': 'item'})
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:58.692733', 'stdout': '     schemaname     |        tablename        \n--------------------+-------------------------\n pg_catalog         | pg_statistic\n pg_catalog         | pg_type\n pg_catalog         | pg_foreign_table\n pg_catalog         | pg_authid\n pg_catalog         | pg_statistic_ext_data\n pg_catalog         | pg_largeobject\n pg_catalog         | pg_user_mapping\n pg_catalog         | pg_subscription\n pg_catalog         | pg_attribute\n pg_catalog         | pg_proc\n pg_catalog         | pg_class\n pg_catalog         | pg_attrdef\n pg_catalog         | pg_constraint\n pg_catalog         | pg_inherits\n pg_catalog         | pg_index\n pg_catalog         | pg_operator\n pg_catalog         | pg_opfamily\n pg_catalog         | pg_opclass\n pg_catalog         | pg_am\n pg_catalog         | pg_amop\n pg_catalog         | pg_amproc\n pg_catalog         | pg_language\n pg_catalog         | pg_largeobject_metadata\n pg_catalog         | pg_aggregate\n pg_catalog         | pg_statistic_ext\n pg_catalog         | pg_rewrite\n pg_catalog         | pg_trigger\n pg_catalog         | pg_event_trigger\n pg_catalog         | pg_description\n pg_catalog         | pg_cast\n pg_catalog         | pg_enum\n pg_catalog         | pg_namespace\n pg_catalog         | pg_conversion\n pg_catalog         | pg_depend\n pg_catalog         | pg_database\n pg_catalog         | pg_db_role_setting\n pg_catalog         | pg_tablespace\n pg_catalog         | pg_auth_members\n pg_catalog         | pg_shdepend\n pg_catalog         | pg_shdescription\n pg_catalog         | pg_ts_config\n pg_catalog         | pg_ts_config_map\n pg_catalog         | pg_ts_dict\n pg_catalog         | pg_ts_parser\n pg_catalog         | pg_ts_template\n pg_catalog         | pg_extension\n pg_catalog         | pg_foreign_data_wrapper\n pg_catalog         | pg_foreign_server\n pg_catalog         | pg_policy\n pg_catalog         | pg_replication_origin\n pg_catalog         | pg_default_acl\n pg_catalog         | pg_init_privs\n pg_catalog         | pg_seclabel\n pg_catalog         | pg_shseclabel\n pg_catalog         | pg_collation\n pg_catalog         | pg_partitioned_table\n pg_catalog         | pg_range\n pg_catalog         | pg_transform\n pg_catalog         | pg_sequence\n pg_catalog         | pg_publication\n pg_catalog         | pg_publication_rel\n pg_catalog         | pg_subscription_rel\n information_schema | sql_implementation_info\n information_schema | sql_parts\n information_schema | sql_sizing\n information_schema | sql_features\n(66 строк)', 'cmd': 'sudo -iu postgres psql -c "SELECT schemaname, tablename FROM pg_catalog.pg_tables;"', 'rc': 0, 'start': '2025-02-19 17:49:58.566144', 'stderr': '', 'delta': '0:00:00.126589', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT schemaname, tablename FROM pg_catalog.pg_tables;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['     schemaname     |        tablename        ', '--------------------+-------------------------', ' pg_catalog         | pg_statistic', ' pg_catalog         | pg_type', ' pg_catalog         | pg_foreign_table', ' pg_catalog         | pg_authid', ' pg_catalog         | pg_statistic_ext_data', ' pg_catalog         | pg_largeobject', ' pg_catalog         | pg_user_mapping', ' pg_catalog         | pg_subscription', ' pg_catalog         | pg_attribute', ' pg_catalog         | pg_proc', ' pg_catalog         | pg_class', ' pg_catalog         | pg_attrdef', ' pg_catalog         | pg_constraint', ' pg_catalog         | pg_inherits', ' pg_catalog         | pg_index', ' pg_catalog         | pg_operator', ' pg_catalog         | pg_opfamily', ' pg_catalog         | pg_opclass', ' pg_catalog         | pg_am', ' pg_catalog         | pg_amop', ' pg_catalog         | pg_amproc', ' pg_catalog         | pg_language', ' pg_catalog         | pg_largeobject_metadata', ' pg_catalog         | pg_aggregate', ' pg_catalog         | pg_statistic_ext', ' pg_catalog         | pg_rewrite', ' pg_catalog         | pg_trigger', ' pg_catalog         | pg_event_trigger', ' pg_catalog         | pg_description', ' pg_catalog         | pg_cast', ' pg_catalog         | pg_enum', ' pg_catalog         | pg_namespace', ' pg_catalog         | pg_conversion', ' pg_catalog         | pg_depend', ' pg_catalog         | pg_database', ' pg_catalog         | pg_db_role_setting', ' pg_catalog         | pg_tablespace', ' pg_catalog         | pg_auth_members', ' pg_catalog         | pg_shdepend', ' pg_catalog         | pg_shdescription', ' pg_catalog         | pg_ts_config', ' pg_catalog         | pg_ts_config_map', ' pg_catalog         | pg_ts_dict', ' pg_catalog         | pg_ts_parser', ' pg_catalog         | pg_ts_template', ' pg_catalog         | pg_extension', ' pg_catalog         | pg_foreign_data_wrapper', ' pg_catalog         | pg_foreign_server', ' pg_catalog         | pg_policy', ' pg_catalog         | pg_replication_origin', ' pg_catalog         | pg_default_acl', ' pg_catalog         | pg_init_privs', ' pg_catalog         | pg_seclabel', ' pg_catalog         | pg_shseclabel', ' pg_catalog         | pg_collation', ' pg_catalog         | pg_partitioned_table', ' pg_catalog         | pg_range', ' pg_catalog         | pg_transform', ' pg_catalog         | pg_sequence', ' pg_catalog         | pg_publication', ' pg_catalog         | pg_publication_rel', ' pg_catalog         | pg_subscription_rel', ' information_schema | sql_implementation_info', ' information_schema | sql_parts', ' information_schema | sql_sizing', ' information_schema | sql_features', '(66 строк)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT schemaname, tablename FROM pg_catalog.pg_tables;', 'ansible_loop_var': 'item'})
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:59.316381', 'stdout': ' archive_mode \n--------------\n on\n(1 строка)', 'cmd': 'sudo -iu postgres psql -c "SHOW archive_mode;"', 'rc': 0, 'start': '2025-02-19 17:49:59.197104', 'stderr': '', 'delta': '0:00:00.119277', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SHOW archive_mode;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': [' archive_mode ', '--------------', ' on', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': 'SHOW archive_mode;', 'ansible_loop_var': 'item'})
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:49:59.931194', 'stdout': ' archive_command \n-----------------\n \n(1 строка)', 'cmd': 'sudo -iu postgres psql -c "SHOW archive_command;"', 'rc': 0, 'start': '2025-02-19 17:49:59.814480', 'stderr': '', 'delta': '0:00:00.116714', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SHOW archive_command;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': [' archive_command ', '-----------------', ' ', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': 'SHOW archive_command;', 'ansible_loop_var': 'item'})

TASK [../roles/master_check_and_activity : PostgreSQL master activity] *********
changed: [master] => (item=DROP SCHEMA IF EXISTS test_schema CASCADE; CREATE SCHEMA test_schema;)
changed: [master] => (item=CREATE TABLE test_schema.test_table(id serial primary key, value varchar(50));)
changed: [master] => (item=INSERT INTO test_schema.test_table(value) VALUES ('first'),('second');)

TASK [../roles/master_check_and_activity : Store activity to file] *************
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:50:05.059311', 'stdout': 'CREATE SCHEMA', 'cmd': 'sudo -iu postgres psql -c "DROP SCHEMA IF EXISTS test_schema CASCADE; CREATE SCHEMA test_schema;"', 'rc': 0, 'start': '2025-02-19 17:50:04.935494', 'stderr': 'NOTICE:  schema "test_schema" does not exist, skipping', 'delta': '0:00:00.123817', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "DROP SCHEMA IF EXISTS test_schema CASCADE; CREATE SCHEMA test_schema;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['CREATE SCHEMA'], 'stderr_lines': ['NOTICE:  schema "test_schema" does not exist, skipping'], 'failed': False, 'item': 'DROP SCHEMA IF EXISTS test_schema CASCADE; CREATE SCHEMA test_schema;', 'ansible_loop_var': 'item'})
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:50:05.707379', 'stdout': 'CREATE TABLE', 'cmd': 'sudo -iu postgres psql -c "CREATE TABLE test_schema.test_table(id serial primary key, value varchar(50));"', 'rc': 0, 'start': '2025-02-19 17:50:05.567802', 'stderr': '', 'delta': '0:00:00.139577', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "CREATE TABLE test_schema.test_table(id serial primary key, value varchar(50));"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['CREATE TABLE'], 'stderr_lines': [], 'failed': False, 'item': 'CREATE TABLE test_schema.test_table(id serial primary key, value varchar(50));', 'ansible_loop_var': 'item'})
ok: [master -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:50:06.331478', 'stdout': 'INSERT 0 2', 'cmd': 'sudo -iu postgres psql -c "INSERT INTO test_schema.test_table(value) VALUES (\'first\'),(\'second\');"', 'rc': 0, 'start': '2025-02-19 17:50:06.208624', 'stderr': '', 'delta': '0:00:00.122854', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "INSERT INTO test_schema.test_table(value) VALUES (\'first\'),(\'second\');"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['INSERT 0 2'], 'stderr_lines': [], 'failed': False, 'item': "INSERT INTO test_schema.test_table(value) VALUES ('first'),('second');", 'ansible_loop_var': 'item'})

PLAY RECAP *********************************************************************
master                     : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

##### ... что есть на мастере


<details><summary>см. результат `SELECT application_name, state, sync_priority, sync_state FROM pg_stat_replication`</summary>

```text
-- SELECT application_name, state, sync_priority, sync_state FROM pg_stat_replication;
 application_name |   state   | sync_priority | sync_state 
------------------+-----------+---------------+------------
 walreceiver      | streaming |             0 | async
(1 строка)
```

</details>

<details><summary>см. результат `SELECT * FROM pg_stat_replication`</summary>

```text
-- SELECT * FROM pg_stat_replication;
  pid  | usesysid |  usename   | application_name |  client_addr  | client_hostname | client_port |         backend_start         | backend_xmin |   state   | sent_lsn  | write_lsn | flush_lsn | replay_lsn |    write_lag    |   flush_lag    |   replay_lag    | sync_priority | sync_state |          reply_time           
-------+----------+------------+------------------+---------------+-----------------+-------------+-------------------------------+--------------+-----------+-----------+-----------+-----------+------------+-----------------+----------------+-----------------+---------------+------------+-------------------------------
 29243 |    16384 | replicator | walreceiver      | 192.168.40.11 |                 |       36038 | 2025-02-19 17:49:41.469113+00 |              | streaming | 0/3000060 | 0/3000060 | 0/3000060 | 0/3000060  | 00:00:00.079097 | 00:00:00.08052 | 00:00:00.080527 |             0 | async      | 2025-02-19 17:49:55.318138+00
(1 строка)
```

</details>

Полученные ниже результаты пригодятся для сравнения с изменениями на реплике после CRUD-"активности" на мастере:


<details><summary>см. результат `SELECT datname AS databases FROM pg_database`</summary>

```text
-- SELECT datname AS database_name FROM pg_database;
 database_name 
---------------
 postgres
 template1
 template0
(3 строки)
```

</details>

<details><summary>см. результат `SELECT schema_name FROM information_schema.schemata`</summary>

```text
-- SELECT schema_name FROM information_schema.schemata;
    schema_name     
--------------------
 pg_toast
 pg_catalog
 public
 information_schema
(4 строки)
```

</details>

<details><summary>см. результат `SELECT schemaname, tablename FROM pg_catalog.pg_tables`</summary>

```text
-- SELECT schemaname, tablename FROM pg_catalog.pg_tables;
     schemaname     |        tablename        
--------------------+-------------------------
 pg_catalog         | pg_statistic
 pg_catalog         | pg_type
 pg_catalog         | pg_foreign_table
 pg_catalog         | pg_authid
 pg_catalog         | pg_statistic_ext_data
 pg_catalog         | pg_largeobject
 pg_catalog         | pg_user_mapping
 pg_catalog         | pg_subscription
 pg_catalog         | pg_attribute
 pg_catalog         | pg_proc
 pg_catalog         | pg_class
 pg_catalog         | pg_attrdef
 pg_catalog         | pg_constraint
 pg_catalog         | pg_inherits
 pg_catalog         | pg_index
 pg_catalog         | pg_operator
 pg_catalog         | pg_opfamily
 pg_catalog         | pg_opclass
 pg_catalog         | pg_am
 pg_catalog         | pg_amop
 pg_catalog         | pg_amproc
 pg_catalog         | pg_language
 pg_catalog         | pg_largeobject_metadata
 pg_catalog         | pg_aggregate
 pg_catalog         | pg_statistic_ext
 pg_catalog         | pg_rewrite
 pg_catalog         | pg_trigger
 pg_catalog         | pg_event_trigger
 pg_catalog         | pg_description
 pg_catalog         | pg_cast
 pg_catalog         | pg_enum
 pg_catalog         | pg_namespace
 pg_catalog         | pg_conversion
 pg_catalog         | pg_depend
 pg_catalog         | pg_database
 pg_catalog         | pg_db_role_setting
 pg_catalog         | pg_tablespace
 pg_catalog         | pg_auth_members
 pg_catalog         | pg_shdepend
 pg_catalog         | pg_shdescription
 pg_catalog         | pg_ts_config
 pg_catalog         | pg_ts_config_map
 pg_catalog         | pg_ts_dict
 pg_catalog         | pg_ts_parser
 pg_catalog         | pg_ts_template
 pg_catalog         | pg_extension
 pg_catalog         | pg_foreign_data_wrapper
 pg_catalog         | pg_foreign_server
 pg_catalog         | pg_policy
 pg_catalog         | pg_replication_origin
 pg_catalog         | pg_default_acl
 pg_catalog         | pg_init_privs
 pg_catalog         | pg_seclabel
 pg_catalog         | pg_shseclabel
 pg_catalog         | pg_collation
 pg_catalog         | pg_partitioned_table
 pg_catalog         | pg_range
 pg_catalog         | pg_transform
 pg_catalog         | pg_sequence
 pg_catalog         | pg_publication
 pg_catalog         | pg_publication_rel
 pg_catalog         | pg_subscription_rel
 information_schema | sql_implementation_info
 information_schema | sql_parts
 information_schema | sql_sizing
 information_schema | sql_features
(66 строк)
```

</details>

##### ... совершаем CRUD-"действия" на мастере


<details><summary>см. лог выполнения `DROP SCHEMA IF EXISTS test_schema CASCADE ... CREATE SCHEMA test_schema`</summary>

```text
-- DROP SCHEMA IF EXISTS test_schema CASCADE; CREATE SCHEMA test_schema;
CREATE SCHEMA
```

</details>

<details><summary>см. лог выполнения `CREATE TABLE test_schema.test_table ...`</summary>

```text
-- CREATE TABLE test_schema.test_table(id serial primary key, value varchar(50));
CREATE TABLE
```

</details>

<details><summary>см. лог выполнения `INSERT INTO test_schema.test_table VALUES ...`</summary>

```text
-- INSERT INTO test_schema.test_table(value) VALUES ('first'),('second');
INSERT 0 2
```

</details>

##### Что есть на реплике после CRUD-"активности" на мастере

```shell
ansible-playbook playbooks/replica_check_after.yml > ../files/005_playbooks-replica_check_after.yml.txt
```


<details><summary>см. лог выполнения `playbooks/replica_check_after.yml`</summary>

```text

PLAY [Playbook of check replica after master activity] *************************

TASK [Gathering Facts] *********************************************************
ok: [replica]

TASK [../roles/replica_check_after : PostgreSQL master checker] ****************
changed: [replica] => (item=SELECT datname AS database_name FROM pg_database;)
changed: [replica] => (item=SELECT schema_name FROM information_schema.schemata;)
changed: [replica] => (item=SELECT schemaname, tablename FROM pg_catalog.pg_tables;)
changed: [replica] => (item=SELECT * FROM test_schema.test_table;)

TASK [../roles/replica_check_after : Store check to file] **********************
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:50:11.954562', 'stdout': ' database_name \n---------------\n postgres\n template1\n template0\n(3 строки)', 'cmd': 'sudo -iu postgres psql -c "SELECT datname AS database_name FROM pg_database;"', 'rc': 0, 'start': '2025-02-19 17:50:11.766685', 'stderr': '', 'delta': '0:00:00.187877', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT datname AS database_name FROM pg_database;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': [' database_name ', '---------------', ' postgres', ' template1', ' template0', '(3 строки)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT datname AS database_name FROM pg_database;', 'ansible_loop_var': 'item'})
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:50:12.581888', 'stdout': '    schema_name     \n--------------------\n pg_toast\n pg_catalog\n public\n information_schema\n test_schema\n(5 строк)', 'cmd': 'sudo -iu postgres psql -c "SELECT schema_name FROM information_schema.schemata;"', 'rc': 0, 'start': '2025-02-19 17:50:12.460102', 'stderr': '', 'delta': '0:00:00.121786', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT schema_name FROM information_schema.schemata;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['    schema_name     ', '--------------------', ' pg_toast', ' pg_catalog', ' public', ' information_schema', ' test_schema', '(5 строк)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT schema_name FROM information_schema.schemata;', 'ansible_loop_var': 'item'})
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:50:13.254903', 'stdout': '     schemaname     |        tablename        \n--------------------+-------------------------\n test_schema        | test_table\n pg_catalog         | pg_statistic\n pg_catalog         | pg_type\n pg_catalog         | pg_foreign_table\n pg_catalog         | pg_authid\n pg_catalog         | pg_statistic_ext_data\n pg_catalog         | pg_largeobject\n pg_catalog         | pg_user_mapping\n pg_catalog         | pg_subscription\n pg_catalog         | pg_attribute\n pg_catalog         | pg_proc\n pg_catalog         | pg_class\n pg_catalog         | pg_attrdef\n pg_catalog         | pg_constraint\n pg_catalog         | pg_inherits\n pg_catalog         | pg_index\n pg_catalog         | pg_operator\n pg_catalog         | pg_opfamily\n pg_catalog         | pg_opclass\n pg_catalog         | pg_am\n pg_catalog         | pg_amop\n pg_catalog         | pg_amproc\n pg_catalog         | pg_language\n pg_catalog         | pg_largeobject_metadata\n pg_catalog         | pg_aggregate\n pg_catalog         | pg_statistic_ext\n pg_catalog         | pg_rewrite\n pg_catalog         | pg_trigger\n pg_catalog         | pg_event_trigger\n pg_catalog         | pg_description\n pg_catalog         | pg_cast\n pg_catalog         | pg_enum\n pg_catalog         | pg_namespace\n pg_catalog         | pg_conversion\n pg_catalog         | pg_depend\n pg_catalog         | pg_database\n pg_catalog         | pg_db_role_setting\n pg_catalog         | pg_tablespace\n pg_catalog         | pg_auth_members\n pg_catalog         | pg_shdepend\n pg_catalog         | pg_shdescription\n pg_catalog         | pg_ts_config\n pg_catalog         | pg_ts_config_map\n pg_catalog         | pg_ts_dict\n pg_catalog         | pg_ts_parser\n pg_catalog         | pg_ts_template\n pg_catalog         | pg_extension\n pg_catalog         | pg_foreign_data_wrapper\n pg_catalog         | pg_foreign_server\n pg_catalog         | pg_policy\n pg_catalog         | pg_replication_origin\n pg_catalog         | pg_default_acl\n pg_catalog         | pg_init_privs\n pg_catalog         | pg_seclabel\n pg_catalog         | pg_shseclabel\n pg_catalog         | pg_collation\n pg_catalog         | pg_partitioned_table\n pg_catalog         | pg_range\n pg_catalog         | pg_transform\n pg_catalog         | pg_sequence\n pg_catalog         | pg_publication\n pg_catalog         | pg_publication_rel\n pg_catalog         | pg_subscription_rel\n information_schema | sql_implementation_info\n information_schema | sql_parts\n information_schema | sql_sizing\n information_schema | sql_features\n(67 строк)', 'cmd': 'sudo -iu postgres psql -c "SELECT schemaname, tablename FROM pg_catalog.pg_tables;"', 'rc': 0, 'start': '2025-02-19 17:50:13.111206', 'stderr': '', 'delta': '0:00:00.143697', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT schemaname, tablename FROM pg_catalog.pg_tables;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['     schemaname     |        tablename        ', '--------------------+-------------------------', ' test_schema        | test_table', ' pg_catalog         | pg_statistic', ' pg_catalog         | pg_type', ' pg_catalog         | pg_foreign_table', ' pg_catalog         | pg_authid', ' pg_catalog         | pg_statistic_ext_data', ' pg_catalog         | pg_largeobject', ' pg_catalog         | pg_user_mapping', ' pg_catalog         | pg_subscription', ' pg_catalog         | pg_attribute', ' pg_catalog         | pg_proc', ' pg_catalog         | pg_class', ' pg_catalog         | pg_attrdef', ' pg_catalog         | pg_constraint', ' pg_catalog         | pg_inherits', ' pg_catalog         | pg_index', ' pg_catalog         | pg_operator', ' pg_catalog         | pg_opfamily', ' pg_catalog         | pg_opclass', ' pg_catalog         | pg_am', ' pg_catalog         | pg_amop', ' pg_catalog         | pg_amproc', ' pg_catalog         | pg_language', ' pg_catalog         | pg_largeobject_metadata', ' pg_catalog         | pg_aggregate', ' pg_catalog         | pg_statistic_ext', ' pg_catalog         | pg_rewrite', ' pg_catalog         | pg_trigger', ' pg_catalog         | pg_event_trigger', ' pg_catalog         | pg_description', ' pg_catalog         | pg_cast', ' pg_catalog         | pg_enum', ' pg_catalog         | pg_namespace', ' pg_catalog         | pg_conversion', ' pg_catalog         | pg_depend', ' pg_catalog         | pg_database', ' pg_catalog         | pg_db_role_setting', ' pg_catalog         | pg_tablespace', ' pg_catalog         | pg_auth_members', ' pg_catalog         | pg_shdepend', ' pg_catalog         | pg_shdescription', ' pg_catalog         | pg_ts_config', ' pg_catalog         | pg_ts_config_map', ' pg_catalog         | pg_ts_dict', ' pg_catalog         | pg_ts_parser', ' pg_catalog         | pg_ts_template', ' pg_catalog         | pg_extension', ' pg_catalog         | pg_foreign_data_wrapper', ' pg_catalog         | pg_foreign_server', ' pg_catalog         | pg_policy', ' pg_catalog         | pg_replication_origin', ' pg_catalog         | pg_default_acl', ' pg_catalog         | pg_init_privs', ' pg_catalog         | pg_seclabel', ' pg_catalog         | pg_shseclabel', ' pg_catalog         | pg_collation', ' pg_catalog         | pg_partitioned_table', ' pg_catalog         | pg_range', ' pg_catalog         | pg_transform', ' pg_catalog         | pg_sequence', ' pg_catalog         | pg_publication', ' pg_catalog         | pg_publication_rel', ' pg_catalog         | pg_subscription_rel', ' information_schema | sql_implementation_info', ' information_schema | sql_parts', ' information_schema | sql_sizing', ' information_schema | sql_features', '(67 строк)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT schemaname, tablename FROM pg_catalog.pg_tables;', 'ansible_loop_var': 'item'})
ok: [replica -> localhost] => (item={'changed': True, 'end': '2025-02-19 17:50:13.887858', 'stdout': ' id | value  \n----+--------\n  1 | first\n  2 | second\n(2 строки)', 'cmd': 'sudo -iu postgres psql -c "SELECT * FROM test_schema.test_table;"', 'rc': 0, 'start': '2025-02-19 17:50:13.763644', 'stderr': '', 'delta': '0:00:00.124214', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'sudo -iu postgres psql -c "SELECT * FROM test_schema.test_table;"', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': [' id | value  ', '----+--------', '  1 | first', '  2 | second', '(2 строки)'], 'stderr_lines': [], 'failed': False, 'item': 'SELECT * FROM test_schema.test_table;', 'ansible_loop_var': 'item'})

PLAY RECAP *********************************************************************
replica                    : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

Базы данных не изменились, так как не создавалось новых:


<details><summary>см. результат `SELECT datname AS databases FROM pg_database`</summary>

```text
-- SELECT datname AS database_name FROM pg_database;
 database_name 
---------------
 postgres
 template1
 template0
(3 строки)
```

</details>

Появились сведения о созданной на мастере схеме `test_schema`:


<details><summary>см. результат `SELECT schema_name FROM information_schema.schemata`</summary>

```text
-- SELECT schema_name FROM information_schema.schemata;
    schema_name     
--------------------
 pg_toast
 pg_catalog
 public
 information_schema
 test_schema
(5 строк)
```

</details>

Появились сведения о созданной на мастере таблице `test_table` схемы `test_schema`:


<details><summary>см. результат `SELECT schemaname, tablename FROM pg_catalog.pg_tables`</summary>

```text
-- SELECT schemaname, tablename FROM pg_catalog.pg_tables;
     schemaname     |        tablename        
--------------------+-------------------------
 test_schema        | test_table
 pg_catalog         | pg_statistic
 pg_catalog         | pg_type
 pg_catalog         | pg_foreign_table
 pg_catalog         | pg_authid
 pg_catalog         | pg_statistic_ext_data
 pg_catalog         | pg_largeobject
 pg_catalog         | pg_user_mapping
 pg_catalog         | pg_subscription
 pg_catalog         | pg_attribute
 pg_catalog         | pg_proc
 pg_catalog         | pg_class
 pg_catalog         | pg_attrdef
 pg_catalog         | pg_constraint
 pg_catalog         | pg_inherits
 pg_catalog         | pg_index
 pg_catalog         | pg_operator
 pg_catalog         | pg_opfamily
 pg_catalog         | pg_opclass
 pg_catalog         | pg_am
 pg_catalog         | pg_amop
 pg_catalog         | pg_amproc
 pg_catalog         | pg_language
 pg_catalog         | pg_largeobject_metadata
 pg_catalog         | pg_aggregate
 pg_catalog         | pg_statistic_ext
 pg_catalog         | pg_rewrite
 pg_catalog         | pg_trigger
 pg_catalog         | pg_event_trigger
 pg_catalog         | pg_description
 pg_catalog         | pg_cast
 pg_catalog         | pg_enum
 pg_catalog         | pg_namespace
 pg_catalog         | pg_conversion
 pg_catalog         | pg_depend
 pg_catalog         | pg_database
 pg_catalog         | pg_db_role_setting
 pg_catalog         | pg_tablespace
 pg_catalog         | pg_auth_members
 pg_catalog         | pg_shdepend
 pg_catalog         | pg_shdescription
 pg_catalog         | pg_ts_config
 pg_catalog         | pg_ts_config_map
 pg_catalog         | pg_ts_dict
 pg_catalog         | pg_ts_parser
 pg_catalog         | pg_ts_template
 pg_catalog         | pg_extension
 pg_catalog         | pg_foreign_data_wrapper
 pg_catalog         | pg_foreign_server
 pg_catalog         | pg_policy
 pg_catalog         | pg_replication_origin
 pg_catalog         | pg_default_acl
 pg_catalog         | pg_init_privs
 pg_catalog         | pg_seclabel
 pg_catalog         | pg_shseclabel
 pg_catalog         | pg_collation
 pg_catalog         | pg_partitioned_table
 pg_catalog         | pg_range
 pg_catalog         | pg_transform
 pg_catalog         | pg_sequence
 pg_catalog         | pg_publication
 pg_catalog         | pg_publication_rel
 pg_catalog         | pg_subscription_rel
 information_schema | sql_implementation_info
 information_schema | sql_parts
 information_schema | sql_sizing
 information_schema | sql_features
(67 строк)
```

</details>

Появились реплицированные данные от мастера с таблицы `test_table` схемы `test_schema`:


<details><summary>см. результат `SELECT * FROM test_schema.test_table.txt`</summary>

```text
-- SELECT * FROM test_schema.test_table;
 id | value  
----+--------
  1 | first
  2 | second
(2 строки)
```

</details>

### Barman

#### Вводная 

Barman сначала у меня не заработал до конца. Вопросы в самом конце. Я пробовал на PG11 и PG13. Сейчас репозиторий приведен под PG13. Есть отличие в реплицировании, так как было упразднено в PG12 `recovery.conf`, а его содержание перенесено в `postgresql.conf`.  Вместо этого `recovery.signal` и `standby.signal`. Вместо `trigger_file` переименовали в `promote_trigger_file`. Если не инетересно все это исследование, то просто перейдите к разделу [Barman - сухое изложение](#barman---сухое-изложение)

#### Дополнительно на мастере

```shell
ansible-playbook playbooks/barman_on_master.yml --tags deploy > ../files/010_playbooks-barman_on_master.yml.txt
```


<details><summary>см. лог выполнения `playbooks/barman_on_master.yml`</summary>

```text

PLAY [Playbook of PostgreSQL barman on master] *********************************

TASK [Gathering Facts] *********************************************************
ok: [master]

TASK [../roles/barman_on_master : Create PostgreSQL barman user] ***************
changed: [master] => (item=DROP USER IF EXISTS barman;)
changed: [master] => (item=CREATE USER barman SUPERUSER;)
changed: [master] => (item=ALTER USER barman WITH ENCRYPTED PASSWORD 'barman';)
changed: [master] => (item=DROP USER IF EXISTS superbarman;)

TASK [../roles/barman_on_master : Create PostgreSQL streaming barman user] *****
failed: [master] (item=CREATE USER streaming_barman REPLICATION;) => {"ansible_loop_var": "item", "changed": true, "cmd": "psql postgres -c \"CREATE USER streaming_barman REPLICATION;;\"", "delta": "0:00:00.026038", "end": "2025-02-19 22:07:54.988637", "item": "CREATE USER streaming_barman REPLICATION;", "msg": "non-zero return code", "rc": 1, "start": "2025-02-19 22:07:54.962599", "stderr": "ERROR:  role \"streaming_barman\" already exists", "stderr_lines": ["ERROR:  role \"streaming_barman\" already exists"], "stdout": "", "stdout_lines": []}
changed: [master] => (item=ALTER USER streaming_barman WITH ENCRYPTED PASSWORD 'barman';)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_start_backup(text, boolean, boolean) to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_stop_backup() to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_stop_backup(boolean, boolean) to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_switch_wal() to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_create_restore_point(text) to streaming_barman;)
changed: [master] => (item=GRANT pg_read_all_settings TO streaming_barman;)
changed: [master] => (item=GRANT pg_read_all_stats TO streaming_barman;)

PLAY RECAP *********************************************************************
master                     : ok=2    changed=1    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0   


```

</details>

Промежуточная проверка. Соединения __локально__ работают:


<details><summary>см. PSQL: barman SELECT version()</summary>

```text
-- psql -c 'SELECT version()' -U barman -h 127.0.0.1 postgres
                                                 version                                                 
---------------------------------------------------------------------------------------------------------
 PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit
(1 строка)
```

</details>


<details><summary>см. PSQL: streaming_barman IDENTIFY_SYSTEM</summary>

```text
-- psql -U streaming_barman -h 127.0.0.1 -c "IDENTIFY_SYSTEM" replication=1
      systemid       | timeline |  xlogpos  | dbname 
---------------------+----------+-----------+--------
 7033506171424845899 |        1 | 0/30242E8 | 
(1 строка)
```

</details>

#### На Barman-сервере

Я решил использовать вариант `streaming` режима (то есть не `Rsync via SSH`).

Подробная официальная документация:
* https://docs.pgbarman.org/release/2.15/

Есть еще:
* https://medium.com/coderbunker/implement-backup-with-barman-bb0b44af71f9
* https://blog.dbi-services.com/postgresql-barman-rsync-method-vs-streaming-method/
* https://sidmid.ru/barman-%D0%BC%D0%B5%D0%BD%D0%B5%D0%B4%D0%B6%D0%B5%D1%80-%D0%B1%D1%8D%D0%BA%D0%B0%D0%BF%D0%BE%D0%B2-%D0%B4%D0%BB%D1%8F-%D1%81%D0%B5%D1%80%D0%B2%D0%B5%D1%80%D0%BE%D0%B2-postgresql/
* https://habr.com/ru/company/yoomoney/blog/333844/
* http://innerlife.io/ru/fault-tolerant-postgresql-cluster-part4-2/
* https://virtbox.blogspot.com/2013/11/barman-postgresql-backup-and-recovery.html
* https://oguridatabasetech.com/2018/02/06/barman-error-impossible-to-start-the-backup-check-the-log-for-more-details/
* https://postgrespro.ru/list/thread-id/2371354
* https://itectec.com/database/postgresql-error-receiving-wal-files-with-barman/

Это все привожу потому, что у меня НЕ ВЫХОДИТ получить бекап и наладить передачу WAL.

Подробно.

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags install-postgresql > ../files/011_playbooks-barman_on_backup-install-postgresql.yml.txt
```


<details><summary>см. лог выполнения `playbooks/barman_on_backup.yml --tags install-postgresql`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

TASK [../roles/barman_on_backup : Install PostgreSQL repo] *********************
changed: [backup]

TASK [../roles/barman_on_backup : Install PostgreSQL server] *******************
changed: [backup]

PLAY RECAP *********************************************************************
backup                     : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

__Кстати__: у Barman в зависимостях именно сервер PostgreSQL, одним клиентом psql не обойтись.


Показано, что соединения __удаленно__ тоже работают:


<details><summary>см. PSQL: barman SELECT version()</summary>

```text
-- psql -c 'SELECT version()' -U barman -h 192.168.40.10 postgres
                                                 version                                                 
---------------------------------------------------------------------------------------------------------
 PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit
(1 строка)
```

</details>


<details><summary>см. PSQL: barman streaming_barman IDENTIFY_SYSTEM</summary>

```text
-- psql -U streaming_barman -h 192.168.40.10 -c "IDENTIFY_SYSTEM" replication=1
      systemid       | timeline |  xlogpos  | dbname 
---------------------+----------+-----------+--------
 7033121761252172325 |        1 | 0/30001C0 | 
(1 строка)
```

</details>

Установим и настроим барман


<details><summary>см. общий конфиг `barman.conf`</summary>

```text
[barman]
active = true
barman_user = barman
barman_home = /var/lib/barman
configuration_files_directory = /etc/barman.d
log_file = /var/log/barman/barman.log
log_level = INFO
compression = gzip
retention_policy = REDUNDANCY 3
immediate_checkpoint = true
last_backup_maximum_age = 4 DAYS
minimum_redundancy = 1

```

</details>


<details><summary>см. конфиг подопечного сервера `pg.conf`</summary>

```text
[pg]
description =  "PostgreSQL Streaming Backup"
conninfo = "host=192.168.40.10 user=barman dbname=postgres"
backup_method = postgres

archiver = on
streaming_conninfo = "host=192.168.40.10 user=streaming_barman dbname=postgres"
streaming_archiver = on
slot_name = barman

```

</details>

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags install-and-configure-barman > ../files/012_playbooks-barman_on_backup-install-and-configure-barman.yml.txt
```


<details><summary>см. лог выполнения `playbooks/barman_on_backup.yml --tags install-and-configure-barman`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

TASK [../roles/barman_on_backup : Install EPEL Repo package from standart repo] ***
changed: [backup]

TASK [../roles/barman_on_backup : Yum install Barman requirements] *************
ok: [backup] => (item=postgresql13-libs.x86_64)

TASK [../roles/barman_on_backup : Install Barman package] **********************
changed: [backup]

TASK [../roles/barman_on_backup : Update PATH - /etc/environment - not bug, just feature - for pg_receivexlog OK] ***
changed: [backup]

TASK [../roles/barman_on_backup : Update PATH - ~/.* - not bug, just feature - for pg_receivexlog OK] ***
changed: [backup]

TASK [../roles/barman_on_backup : Configure barman] ****************************
changed: [backup] => (item=/etc/barman.conf)
changed: [backup] => (item=/etc/barman.d/pg.conf)
changed: [backup] => (item=/var/lib/barman/.pgpass)
changed: [backup] => (item=/var/lib/barman/.ssh/)

TASK [../roles/barman_on_backup : Create barman slot] **************************
changed: [backup]

TASK [../roles/barman_on_backup : Barman Cron as timed serviсe] ****************
changed: [backup] => (item=barman-cron.service)
changed: [backup] => (item=barman-cron.timer)

TASK [../roles/barman_on_backup : systemctl enable barman-cron.service] ********
changed: [backup]

TASK [../roles/barman_on_backup : systemctl start barman-cron.timer] ***********
changed: [backup]

TASK [../roles/barman_on_backup : Check barman cron as timed serviсe] **********
changed: [backup]

TASK [../roles/barman_on_backup : Store barman cron as timed serviсe check] ****
changed: [backup -> localhost]

TASK [../roles/barman_on_backup : Barman switch-wal force archive] *************
changed: [backup]

TASK [../roles/barman_on_backup : result of `barman switch-wal --force --archive pg`] ***
ok: [backup] => {
    "msg": {
        "changed": true,
        "cmd": "barman switch-wal --force --archive pg\nexit 0 # because may be fail\n",
        "delta": "0:00:12.941913",
        "end": "2025-02-19 21:54:12.677971",
        "failed": false,
        "rc": 0,
        "start": "2025-02-19 21:53:59.736058",
        "stderr": "",
        "stderr_lines": [],
        "stdout": "The WAL file 000000010000000000000004 has been closed on server 'pg'\nWaiting for the WAL file 000000010000000000000004 from server 'pg' (max: 30 seconds)\nProcessing xlog segments from file archival for pg\n\t000000010000000000000001\nProcessing xlog segments from file archival for pg\n\t000000010000000000000002\nProcessing xlog segments from file archival for pg\n\t000000010000000000000002.00000028.backup\nProcessing xlog segments from file archival for pg\n\t000000010000000000000003\nProcessing xlog segments from file archival for pg\n\t000000010000000000000004",
        "stdout_lines": [
            "The WAL file 000000010000000000000004 has been closed on server 'pg'",
            "Waiting for the WAL file 000000010000000000000004 from server 'pg' (max: 30 seconds)",
            "Processing xlog segments from file archival for pg",
            "\t000000010000000000000001",
            "Processing xlog segments from file archival for pg",
            "\t000000010000000000000002",
            "Processing xlog segments from file archival for pg",
            "\t000000010000000000000002.00000028.backup",
            "Processing xlog segments from file archival for pg",
            "\t000000010000000000000003",
            "Processing xlog segments from file archival for pg",
            "\t000000010000000000000004"
        ]
    }
}

RUNNING HANDLER [../roles/barman_on_backup : systemd-daemon-reload] ************
ok: [backup]

PLAY RECAP *********************************************************************
backup                     : ok=16   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

Сервис  `barman-cron` 

__Замечание__: тут Unit-user может быть barman.

<details><summary>см. код `barman-cron.service`</summary>

```text
[Unit]
Description=Barman cron
Wants=barman-cron.timer

[Service]
User=barman
#User=root
Type=oneshot
#Type=simple
ExecStart=/usr/bin/barman cron

[Install]
WantedBy=multi-user.target
```

</details>


<details><summary>см. код `barman-cron.timer`</summary>

```text
[Unit]
Description=Barman cron scheduled
Requires=barman-cron.service

[Timer]
Unit=barman-cron.service
OnUnitActiveSec=10

[Install]
WantedBy=timers.target
```

</details>

работает:


<details><summary>см. лог работы `barman-cron.service`</summary>

```text
-- journalctl -u barman-cron
-- Logs begin at Пн 2025-02-19 20:59:12 UTC, end at Пн 2025-02-19 21:53:58 UTC. --
ноя 22 21:53:56 backup systemd[1]: Starting Barman cron...
ноя 22 21:53:57 backup barman[18405]: Starting WAL archiving for server pg
ноя 22 21:53:57 backup barman[18405]: Starting streaming archiver for server pg
ноя 22 21:53:57 backup systemd[1]: Started Barman cron.
```

</details>

Но в ходе выполнения есть ошибки

```shell
"stderr_lines": [
    "ERROR: The WAL file 000000010000000000000004 has not been received in 30 seconds"
],
"stdout_lines": [
    "The WAL file 000000010000000000000004 has been closed on server 'pg'",
    "Waiting for the WAL file 000000010000000000000006 from server 'pg' (max: 30 seconds)"
]
```

Смотрим `barman check pg`

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags barman-check > ../files/013_barman-check-001.txt
```

прошел c ошибками


<details><summary>см. лог выполнения `barman-check`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

PLAY RECAP *********************************************************************
backup                     : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

выдержка:

```shell
barman check pg | grep FAILED

    WAL archive: FAILED (please make sure WAL shipping is setup)
    replication slot: FAILED (slot 'barman' not initialised: is 'receive-wal' running?)
    backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
    minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
    receive-wal running: FAILED (See the Barman log file for more details)
```

Дадим полезную нагрузку WAL:

```shell
ansible-playbook playbooks/master_activity.yml > ../files/014_playbooks-master_activity.yml.txt
```


<details><summary>см. лог выполнения `playbooks/master_activity.yml`</summary>

```text

PLAY [Playbook of activity master] *********************************************

TASK [Gathering Facts] *********************************************************
ok: [master]

TASK [../roles/master_activity : PostgreSQL master activity] *******************
changed: [master] => (item=1)
changed: [master] => (item=2)
changed: [master] => (item=3)
changed: [master] => (item=4)
changed: [master] => (item=5)
changed: [master] => (item=6)
changed: [master] => (item=7)
changed: [master] => (item=8)
changed: [master] => (item=9)
changed: [master] => (item=10)

PLAY RECAP *********************************************************************
master                     : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

Повторим отдельно принудительный сбор

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags barman-force-switch-wal > ../files/015_barman-force-switch-wal-001.txt
```


<details><summary>см. лог выполнения `barman-force-switch-wal`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

TASK [../roles/barman_on_backup : Barman switch-wal force archive] *************
changed: [backup]

TASK [../roles/barman_on_backup : result of `barman switch-wal --force --archive pg`] ***
ok: [backup] => {
    "msg": {
        "changed": true,
        "cmd": "barman switch-wal --force --archive pg\nexit 0 # because may be fail\n",
        "delta": "0:00:02.402058",
        "end": "2025-02-19 21:54:33.798727",
        "failed": false,
        "rc": 0,
        "start": "2025-02-19 21:54:31.396669",
        "stderr": "",
        "stderr_lines": [],
        "stdout": "The WAL file 000000010000000000000005 has been closed on server 'pg'\nWaiting for the WAL file 000000010000000000000005 from server 'pg' (max: 30 seconds)\nProcessing xlog segments from file archival for pg\n\t000000010000000000000005",
        "stdout_lines": [
            "The WAL file 000000010000000000000005 has been closed on server 'pg'",
            "Waiting for the WAL file 000000010000000000000005 from server 'pg' (max: 30 seconds)",
            "Processing xlog segments from file archival for pg",
            "\t000000010000000000000005"
        ]
    }
}

PLAY RECAP *********************************************************************
backup                     : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

Как видим, есть ошибки

```shell
"stderr_lines": [
    "ERROR: The WAL file 000000010000000000000006 has not been received in 30 seconds"
],
"stdout_lines": [
    "The WAL file 000000010000000000000006 has been closed on server 'pg'",
    "Waiting for the WAL file 000000010000000000000006 from server 'pg' (max: 30 seconds)"
]
```
И ситуация не поменялась.

А вот дальше - __МАГИЯ__. 

Запускаем `barman cron` - хотя это-то уже и так запущено в сервис-службе и по таймеру, вот это выше было


<details><summary>см. лог работы `barman-cron.service`</summary>

```text
-- journalctl -u barman-cron
-- Logs begin at Пн 2025-02-19 20:59:12 UTC, end at Пн 2025-02-19 21:53:58 UTC. --
ноя 22 21:53:56 backup systemd[1]: Starting Barman cron...
ноя 22 21:53:57 backup barman[18405]: Starting WAL archiving for server pg
ноя 22 21:53:57 backup barman[18405]: Starting streaming archiver for server pg
ноя 22 21:53:57 backup systemd[1]: Started Barman cron.
```

</details>

Итак, принудительно `barman cron` 

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags barman-cron
```

и повторим забор wal (тоже самое делалось и ранее в ходе `--tags install-and-configure-barman`)

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags barman-force-switch-wal > ../files/016_barman-force-switch-wal-002.txt
```

O, чудо. Ошибки исполнения `barman switch-wal --force --archive pg` исчезли


<details><summary>см. лог выполнения `barman-force-switch-wal`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

TASK [../roles/barman_on_backup : Barman switch-wal force archive] *************
changed: [backup]

TASK [../roles/barman_on_backup : result of `barman switch-wal --force --archive pg`] ***
ok: [backup] => {
    "msg": {
        "changed": true,
        "cmd": "barman switch-wal --force --archive pg\nexit 0 # because may be fail\n",
        "delta": "0:00:02.685046",
        "end": "2025-02-19 21:54:45.006814",
        "failed": false,
        "rc": 0,
        "start": "2025-02-19 21:54:42.321768",
        "stderr": "",
        "stderr_lines": [],
        "stdout": "The WAL file 000000010000000000000006 has been closed on server 'pg'\nWaiting for the WAL file 000000010000000000000006 from server 'pg' (max: 30 seconds)\nProcessing xlog segments from file archival for pg\n\t000000010000000000000006",
        "stdout_lines": [
            "The WAL file 000000010000000000000006 has been closed on server 'pg'",
            "Waiting for the WAL file 000000010000000000000006 from server 'pg' (max: 30 seconds)",
            "Processing xlog segments from file archival for pg",
            "\t000000010000000000000006"
        ]
    }
}

PLAY RECAP *********************************************************************
backup                     : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

Выдержка:

```text
The WAL file t000000010000000000000006 has been closed on server 'pg'
Waiting for the WAL file t000000010000000000000006 from server 'pg' (max: 30 seconds)
Processing xlog segments from streaming for pg
t000000010000000000000006
```

При этом и в чеке теперь нет обшибок с WAL (это также сохранится и при перезагрузке системы, будет FAILED и потом самодиагностируется в OK)

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags barman-check > ../files/017_barman-check-002.txt
```


<details><summary>см. лог выполнения `barman-check`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

TASK [../roles/barman_on_backup : barman check] ********************************
changed: [backup]

TASK [../roles/barman_on_backup : result of `barman-check`] ********************
ok: [backup] => {
    "msg": "Server pg:\n\tPostgreSQL: OK\n\tsuperuser or standard user with backup privileges: OK\n\tPostgreSQL streaming: OK\n\twal_level: OK\n\treplication slot: OK\n\tdirectories: OK\n\tretention policy settings: OK\n\tbackup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)\n\tcompression settings: OK\n\tfailed backups: OK (there are 0 failed backups)\n\tminimum redundancy requirements: FAILED (have 0 backups, expected at least 1)\n\tpg_basebackup: OK\n\tpg_basebackup compatible: OK\n\tpg_basebackup supports tablespaces mapping: OK\n\tsystemid coherence: OK (no system Id stored on disk)\n\tpg_receivexlog: OK\n\tpg_receivexlog compatible: OK\n\treceive-wal running: OK\n\tarchive_mode: OK\n\tarchive_command: OK\n\tcontinuous archiving: OK\n\tarchiver errors: OK"
}

PLAY RECAP *********************************************************************
backup                     : ok=3    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

Осталось FAILED только связанное с бекапом 

```shell
Server pg:
    ...
    backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
    ...
    minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
    ...
```

Кроме того, все эти действия не позволяют делать `backup`, точнее он просто виснет

```shell
sudo su - barman

barman backup pg
    Starting backup using postgres method for server pg in /var/lib/barman/pg/base/20250219T001134
    Backup start at LSN: 0/7000060 (000000010000000000000007, 00000060)
    Starting backup copy via pg_basebackup for 20250219T001134
```
... и долгая-долгая тишина... вроде как, ничего не происходит.

но если посмотреть в параллельные процессы, то видно

```shell
barman backup pg &
    [1] 22848
    -bash-4.2$ Starting backup using postgres method for server pg in /var/lib/barman/pg/base/20250219T001134
    Backup start at LSN: 0/9000148 (000000010000000000000009, 00000148)
    Starting backup copy via pg_basebackup for 20250219T001134 <----.
                                                                    |
                                                                    |
barman list-backup pg                                               |
    pg 20250219T001134 - STARTED <-------- вроде норм --------------'
```

```shell
ps ux | grep backup

     barman    3545  2.6  8.1 263540 19688 pts/0    S    09:09   0:00 /usr/bin/python2 /bin/barman backup pg
 --> barman    3548  3.3  1.6 180800  3864 pts/0    S    09:09   0:00 /bin/pg_basebackup --dbname=dbname=replication host=192.168.40.10 options=-cdatestyle=iso replication=true user=streaming_barman application_name=barman_streaming_backup -v --no-password --pgdata=/var/lib/barman/pg/base/20250219T001134/data --no-slot --wal-method=none --checkpoint=fast
     barman    3553  0.0  0.4 112812   976 pts/0    S+   09:09   0:00 grep --color=auto backup
```

Висит. Ничего не происходит.

И очень смущают аргументы без кавычек

```shell
/bin/pg_basebackup --dbname=dbname=replication host=192.168.40.10 options=-cdatestyle=iso replication=true user=streaming_barman application_name=barman_streaming_backup -v --no-password --pgdata=/var/lib/barman/pg/base/20250219T001134/data --no-slot --wal-method=none --checkpoint=fast

    pg_basebackup: error: too many command-line arguments (first is "host=192.168.40.10")
    Try "pg_basebackup --help" for more information.

```
Они должны быть такие 

```shell
/bin/pg_basebackup --dbname='dbname=replication host=192.168.40.10 options=-cdatestyle=iso replication=true user=streaming_barman application_name=barman_streaming_backup' -v --no-password --pgdata=/var/lib/barman/pg/base/20250219T001134/data --no-slot --wal-method=none --checkpoint=fast

    pg_basebackup: initiating base backup, waiting for checkpoint to complete
    pg_basebackup: checkpoint completed
    NOTICE:  base backup done, waiting for required WAL segments to be archived
    WARNING:  still waiting for all required WAL segments to be archived (60 seconds elapsed)
    HINT:  Check that your archive_command is executing properly.  You can safely cancel this backup, but the database backup will not be usable without all the WAL segments.
    WARNING:  still waiting for all required WAL segments to be archived (120 seconds elapsed)
    HINT:  Check that your archive_command is executing properly.  You can safely cancel this backup, but the database backup will not be usable without all the WAL segments.

```

При этом 


<details><summary>см. SQL: `SHOW archive_command`</summary>

```text
-- SHOW archive_command;
 archive_command 
-----------------
 
(1 строка)
```

</details>


<details><summary>см. SQL: `SHOW archive_mode`</summary>

```text
-- SHOW archive_mode;
 archive_mode 
--------------
 on
(1 строка)
```

</details>

### Вот тут нужно добиться все же SSH

Так, смотрим тут https://docs.pgbarman.org/release/2.15/#wal-archiving-via-archive_command

```text
From Barman 2.6, the recommended way to safely and reliably archive WAL files to Barman via archive_command is to use the barman-wal-archive command contained in the barman-cli package, distributed via EnterpriseDB public repositories and available under GNU GPL 3 licence. barman-cli must be installed on each PostgreSQL server that is part of the Barman cluster.

...

You can check that barman-wal-archive can connect to the Barman server, and that the required PostgreSQL server is configured in Barman to accept incoming WAL files with the following command:

barman-wal-archive --test backup pg DUMMY
```

исполнится успешно

```shell
[root@master vagrant]# barman-wal-archive --test backup pg DUMMY
```

При этом

```shell
[root@master vagrant]# cat /var/lib/pgsql/13/data/postgresql.conf | grep archive_command
# https://docs.pgbarman.org/release/2.15/#wal-archiving-via-archive_command
archive_command = 'barman-wal-archive backup pg %p'

[root@master vagrant]# cat /var/lib/pgsql/13/data/postgresql.conf | grep archive_mode
archive_mode = on

[root@master vagrant]# cat /var/lib/pgsql/13/data/postgresql.conf | grep wal_level
wal_level = replica # ВАЖНО В КОНТЕКСТЕ ЗАДАЧИ - replica
```

Осталось FAILED связанное с бекапом 

```shell
barman check pg
Server pg:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
 -->    backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
 -->    minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK

```

```shell
barman  show-server pg
Server pg:
        active: True
        archive_timeout: 0
        archiver: False
        archiver_batch_size: 0
        backup_directory: /var/lib/barman/pg
        backup_method: postgres
        backup_options: BackupOptions(['concurrent_backup'])
        bandwidth_limit: None
        barman_home: /var/lib/barman
        barman_lock_directory: /var/lib/barman
        basebackup_retry_sleep: 30
        basebackup_retry_times: 0
        basebackups_directory: /var/lib/barman/pg/base
        check_timeout: 30
        checkpoint_timeout: 300
        compression: gzip
        config_file: /var/lib/pgsql/13/data/postgresql.conf
        connection_error: None
        conninfo: host=192.168.40.10 user=barman dbname=postgres
        create_slot: manual
        current_lsn: 0/D01CBF0
        current_size: 25572051
        current_xlog: 00000001000000000000000D
        custom_compression_filter: None
        custom_decompression_filter: None
        data_checksums: off
        data_directory: /var/lib/pgsql/13/data
        description: PostgreSQL Streaming Backup
        disabled: False
        errors_directory: /var/lib/barman/pg/errors
        forward_config_path: False
        has_backup_privileges: True
        hba_file: /var/lib/pgsql/13/data/pg_hba.conf
        hot_standby: on
        ident_file: /var/lib/pgsql/13/data/pg_ident.conf
        immediate_checkpoint: True
        incoming_wals_directory: /var/lib/barman/pg/incoming
        is_in_recovery: False
        is_superuser: True
        last_backup_maximum_age: 4 days (WARNING! latest backup is No available backups old)
        max_incoming_wals_queue: None
        max_replication_slots: 10
        max_wal_senders: 10
        minimum_redundancy: 1
        msg_list: []
        name: pg
        network_compression: False
        parallel_jobs: 1
        passive_node: False
        path_prefix: None
        pg_basebackup_bwlimit: True
        pg_basebackup_compatible: True
        pg_basebackup_installed: True
        pg_basebackup_path: /bin/pg_basebackup
        pg_basebackup_tbls_mapping: True
        pg_basebackup_version: 13.5
        pg_receivexlog_compatible: True
        pg_receivexlog_installed: True
        pg_receivexlog_path: /usr/pgsql-13/bin/pg_receivewal
        pg_receivexlog_supports_slots: True
        pg_receivexlog_synchronous: False
        pg_receivexlog_version: 13.5
        pgespresso_installed: False
        post_archive_retry_script: None
        post_archive_script: None
        post_backup_retry_script: None
        post_backup_script: None
        post_delete_retry_script: None
        post_delete_script: None
        post_recovery_retry_script: None
        post_recovery_script: None
        post_wal_delete_retry_script: None
        post_wal_delete_script: None
        postgres_systemid: 7032595315385409583
        pre_archive_retry_script: None
        pre_archive_script: None
        pre_backup_retry_script: None
        pre_backup_script: None
        pre_delete_retry_script: None
        pre_delete_script: None
        pre_recovery_retry_script: None
        pre_recovery_script: None
        pre_wal_delete_retry_script: None
        pre_wal_delete_script: None
        primary_ssh_command: None
        recovery_options: RecoveryOptions([])
        replication_slot: Record(slot_name='barman', active=True, restart_lsn='0/D000000')
        replication_slot_support: True
        retention_policy: REDUNDANCY 3
        retention_policy_mode: auto
        reuse_backup: None
        server_txt_version: 13.5
        slot_name: barman
        ssh_command: None
        streaming: True
        streaming_archiver: True
        streaming_archiver_batch_size: 0
        streaming_archiver_name: barman_receive_wal
        streaming_backup_name: barman_streaming_backup
        streaming_conninfo: host=192.168.40.10 user=streaming_barman dbname=postgres
        streaming_supported: True
        streaming_systemid: 7032595315385409583
        streaming_wals_directory: /var/lib/barman/pg/streaming
        synchronous_standby_names: ['standby']
        tablespace_bandwidth_limit: None
        timeline: 1
        wal_compression: off
        wal_keep_size: 0
        wal_level: replica
        wal_retention_policy: MAIN
        wals_directory: /var/lib/barman/pg/wals
        xlog_segment_size: 16777216
        xlogpos: 0/D01CBF0
```

На бекапе

```shell
[root@backup vagrant]# barman show-server pg | grep incoming_wals_directory
        incoming_wals_directory: /var/lib/barman/pg/incoming
```

На маcтере папка такая `/var/lib/pgsql/13/data/pg_wal/` и команда на нем 

```shell
[vagrant@master ~]$ sudo cat /var/lib/pgsql/13/data/postgresql.conf | grep archive_command
# https://docs.pgbarman.org/release/2.15/#wal-archiving-via-archive_command
archive_command = 'barman-wal-archive backup pg %p'

[vagrant@master ~]$ barman-wal-archive backup pg /var/lib/pgsql/13/data/pg_wal
ERROR: Error executing ssh: [Errno 13] Permission denied: '/var/lib/pgsql/13/data/pg_wal'

[vagrant@master ~]$ sudo su

[root@master vagrant]# barman-wal-archive backup pg /var/lib/pgsql/13/data/pg_wal
ERROR: WAL_PATH cannot be a directory: /var/lib/pgsql/13/data/pg_wal

[root@master vagrant]# ls -l /var/lib/pgsql/13/data/pg_wal/
total 180240
-rw-------. 1 postgres postgres 16777216 ноя 20 17:44 000000010000000000000001
-rw-------. 1 postgres postgres 16777216 ноя 20 17:44 000000010000000000000002
-rw-------. 1 postgres postgres      337 ноя 20 17:44 000000010000000000000002.00000028.backup
-rw-------. 1 postgres postgres 16777216 ноя 20 17:46 000000010000000000000003
-rw-------. 1 postgres postgres 16777216 ноя 20 17:47 000000010000000000000004
-rw-------. 1 postgres postgres 16777216 ноя 20 17:48 000000010000000000000005
-rw-------. 1 postgres postgres 16777216 ноя 20 17:49 000000010000000000000006
-rw-------. 1 postgres postgres 16777216 ноя 20 18:41 000000010000000000000007
-rw-------. 1 postgres postgres 16777216 ноя 20 18:41 000000010000000000000008
-rw-------. 1 postgres postgres      337 ноя 20 18:41 000000010000000000000008.00000028.backup
-rw-------. 1 postgres postgres 16777216 ноя 20 18:43 000000010000000000000009
-rw-------. 1 postgres postgres 16777216 ноя 20 18:43 00000001000000000000000A
-rw-------. 1 postgres postgres      337 ноя 20 18:43 00000001000000000000000A.00000028.backup
-rw-------. 1 postgres postgres 16777216 ноя 20 18:43 00000001000000000000000B
drwx------. 2 postgres postgres     4096 ноя 20 18:43 archive_status


[root@master vagrant]# barman-wal-archive backup pg /var/lib/pgsql/13/data/pg_wal/000000010000000000000001 
ERROR: Error executing ssh: [Errno 32] Broken pipe
Exception ValueError: 'I/O operation on closed file' in <bound method _Stream.__del__ of <tarfile._Stream instance at 0x7fbed9d6c638>> ignored

```

Тут меня осенило

```text
ERROR: Error executing ssh: [Errno 32] Broken pipe <--- SSH
```

В документации https://docs.pgbarman.org/release/2.15/#two-typical-scenarios-for-backups в сценарии __1a__ не нужен SSH при STREAMING

```text
This setup, in Barman's terminology, is known as **streaming-only** setup, as it does not require any SSH connection for backup and archiving operations. 
```

Но у тут же сценарий __1b__ https://docs.pgbarman.org/release/2.15/#two-typical-scenarios-for-backups

```text
This alternate approach requires:

    an additional SSH connection that allows the postgres user on the PostgreSQL server to connect as barman user on the Barman server
    the archive_command in PostgreSQL be configured to ship WAL files to Barman

```

barman-wal-archive 192.168.40.12 pg /var/lib/pgsql/13/data/pg_wal/000000010000000000000010

Настроил SSH на MASTER-сервере для пользователя postgresql

[details --no-link]:[~.ssh/authorized_keys](./040/ansible/roles/barman_on_master/files/var/lib/pgsql/.ssh/authorized_keys)
[details --no-link]:[~.ssh/config](./040/ansible/roles/barman_on_master/files/var/lib/pgsql/.ssh/config)
[details --no-link]:[~.ssh/id_rsa](./040/ansible/roles/barman_on_master/files/var/lib/pgsql/.ssh/id_rsa)
[details --no-link]:[~.ssh/id_rsa.pub](./040/ansible/roles/barman_on_master/files/var/lib/pgsql/.ssh/id_rsa.pub)

и SSH на BACKUP-сервере для пользователя barman

[details --no-link]:[~.ssh/authorized_keys](./040/ansible/roles/barman_on_backup/files/var/lib/barman/.ssh/authorized_keys)
[details --no-link]:[~.ssh/id_rsa](./040/ansible/roles/barman_on_backup/files/var/lib/barman/.ssh/id_rsa)
[details --no-link]:[~.ssh/id_rsa.pub](./040/ansible/roles/barman_on_backup/files/var/lib/barman/.ssh/id_rsa.pub)

и бекапирование пошло

```shell
-bash-4.2$ barman backup pg
Starting backup using postgres method for server pg in /var/lib/barman/pg/base/20250219T001134
Backup start at LSN: 0/350001C0 (000000010000000000000035, 000001C0)
Starting backup copy via pg_basebackup for 20250219T001134
Copy done (time: 6 seconds)
Finalising the backup.
This is the first backup for server pg
WAL segments preceding the current backup have been found:
        00000001000000000000002D from server pg has been removed
        00000001000000000000002E from server pg has been removed
        00000001000000000000002F from server pg has been removed
        000000010000000000000030 from server pg has been removed
        000000010000000000000031 from server pg has been removed
        000000010000000000000032 from server pg has been removed
        000000010000000000000033 from server pg has been removed
        000000010000000000000034 from server pg has been removed
Backup size: 24.6 MiB
Backup end at LSN: 0/37000060 (000000010000000000000037, 00000060)
Backup completed (start time: 2025-02-19 23:12:21.653246, elapsed time: 7 seconds)
Processing xlog segments from streaming for pg
        000000010000000000000035
        000000010000000000000036
        000000010000000000000037
 barman check pg

-bash-4.2$ 
Server pg:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: OK (interval provided: 4 days, latest backup age: 10 seconds) <----- WOW
        compression settings: OK
        failed backups: FAILED (there are 8 failed backups)       <----- Горький опыт
        minimum redundancy requirements: OK (have 5 backups, expected at least 1)  <----- WOW
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archive_mode: OK
        archive_command: OK
        continuous archiving: OK
        archiver errors: OK

```

Не понимаю, почему нужно `barman cron` запустить не в сервисе systemd по расписанию изначально, а просто в терминале. Так же пробовал изменить подход запуска служб по расписанию и использовать привычный crontab. 

```yaml
- name: Cron /usr/bin/barman backup
  become_user: barman
  cron:
    name: "barman backup pg"
    minute: "15,45"
    job: "/usr/bin/barman  backup pg"
  tags:
    - crontab

- name: Cron /usr/bin/barman cron
  become_user: barman
  cron:
    name: "barman cron"
    minute: '*'
    job: "/usr/bin/barman cron"
  tags:
    - crontab
```

как выглядит crontab

```shell
$ crontab -l

#Ansible: /usr/bin/barman backup pg
15,45 * * * * /usr/bin/barman  backup pg
#Ansible: /usr/bin/barman cron
* * * * * /usr/bin/barman cron

```

### Barman - сухое изложение

Представим что виртуалки бекапа и мастера еще не "изменялись" (на самом деле у меня есть там конструкция с `--tags redeploy` или `--tags clean`, но это только затруднит понимание)

#### Настройка мастера для будущего Barman на backup-сервере 

```shell
ansible-playbook playbooks/barman_on_master.yml --tags feature-deploy > ../files/110_playbooks-barman_on_master.yml.txt
```


<details><summary>см. лог выполнения `playbooks/barman_on_master.yml`</summary>

```text

PLAY [Playbook of PostgreSQL barman on master] *********************************

TASK [Gathering Facts] *********************************************************
ok: [master]

TASK [../roles/barman_on_master : Create PostgreSQL barman user] ***************
changed: [master] => (item=DROP USER IF EXISTS barman;)
changed: [master] => (item=CREATE USER barman SUPERUSER;)
changed: [master] => (item=ALTER USER barman WITH ENCRYPTED PASSWORD 'barman';)
changed: [master] => (item=DROP USER IF EXISTS superbarman;)

TASK [../roles/barman_on_master : Create PostgreSQL streaming barman user] *****
changed: [master] => (item=CREATE USER streaming_barman REPLICATION;)
changed: [master] => (item=ALTER USER streaming_barman WITH ENCRYPTED PASSWORD 'barman';)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_start_backup(text, boolean, boolean) to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_stop_backup() to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_stop_backup(boolean, boolean) to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_switch_wal() to streaming_barman;)
changed: [master] => (item=GRANT EXECUTE ON FUNCTION pg_create_restore_point(text) to streaming_barman;)
changed: [master] => (item=GRANT pg_read_all_settings TO streaming_barman;)
changed: [master] => (item=GRANT pg_read_all_stats TO streaming_barman;)

TASK [../roles/barman_on_master : Collect SSH and PG files] ********************
changed: [master] => (item=/var/lib/pgsql/13/data/pg_hba.conf)
changed: [master] => (item=/var/lib/pgsql/13/data/postgresql.conf)
changed: [master] => (item=/var/lib/pgsql/.ssh/)

TASK [../roles/barman_on_master : Force restart PostgreSQL] ********************
changed: [master]

TASK [../roles/barman_on_master : Check local PostgreSQL access] ***************
changed: [master] => (item=psql -c 'SELECT version()' -U barman -h 127.0.0.1 postgres)
changed: [master] => (item=psql -U streaming_barman -h 127.0.0.1 -c "IDENTIFY_SYSTEM" replication=1)

TASK [../roles/barman_on_master : Print result of check local PostgreSQL access] ***
ok: [master] => (item={'changed': True, 'end': '2025-02-19 17:50:35.902143', 'stdout': '                                                 version                                                 \n---------------------------------------------------------------------------------------------------------\n PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit\n(1 строка)', 'cmd': "psql -c 'SELECT version()' -U barman -h 127.0.0.1 postgres", 'rc': 0, 'start': '2025-02-19 17:50:35.861212', 'stderr': '', 'delta': '0:00:00.040931', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': "psql -c 'SELECT version()' -U barman -h 127.0.0.1 postgres", 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['                                                 version                                                 ', '---------------------------------------------------------------------------------------------------------', ' PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': "psql -c 'SELECT version()' -U barman -h 127.0.0.1 postgres", 'ansible_loop_var': 'item'}) => {
    "msg": "psql -c 'SELECT version()' -U barman -h 127.0.0.1 postgres\n                                                 version                                                 \n---------------------------------------------------------------------------------------------------------\n PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit\n(1 строка)\n"
}
ok: [master] => (item={'changed': True, 'end': '2025-02-19 17:50:36.495878', 'stdout': '      systemid       | timeline |  xlogpos  | dbname \n---------------------+----------+-----------+--------\n 7033823135014916120 |        1 | 0/30241B0 | \n(1 строка)', 'cmd': 'psql -U streaming_barman -h 127.0.0.1 -c "IDENTIFY_SYSTEM" replication=1', 'rc': 0, 'start': '2025-02-19 17:50:36.456523', 'stderr': '', 'delta': '0:00:00.039355', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'psql -U streaming_barman -h 127.0.0.1 -c "IDENTIFY_SYSTEM" replication=1', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['      systemid       | timeline |  xlogpos  | dbname ', '---------------------+----------+-----------+--------', ' 7033823135014916120 |        1 | 0/30241B0 | ', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': 'psql -U streaming_barman -h 127.0.0.1 -c "IDENTIFY_SYSTEM" replication=1', 'ansible_loop_var': 'item'}) => {
    "msg": "psql -U streaming_barman -h 127.0.0.1 -c \"IDENTIFY_SYSTEM\" replication=1\n      systemid       | timeline |  xlogpos  | dbname \n---------------------+----------+-----------+--------\n 7033823135014916120 |        1 | 0/30241B0 | \n(1 строка)\n"
}

TASK [../roles/barman_on_master : Install EPEL Repo package from standart repo] ***
changed: [master]

TASK [../roles/barman_on_master : Install Barman Client for backup with streaming] ***
changed: [master]

RUNNING HANDLER [../roles/barman_on_master : restart-postgresql] ***************
changed: [master]

PLAY RECAP *********************************************************************
master                     : ok=10   changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   


```

</details>

#### На backup-сервере 

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags feature-deploy > ../files/111_playbooks-barman_on_backup-feature_deploy.yml.txt
```


<details><summary>см. лог выполнения `playbooks/barman_on_backup.yml --tags feature_deploy`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

TASK [../roles/barman_on_backup : Install PostgreSQL repo] *********************
changed: [backup]

TASK [../roles/barman_on_backup : Install PostgreSQL server] *******************
changed: [backup]

TASK [../roles/barman_on_backup : Install EPEL Repo package from standart repo] ***
changed: [backup]

TASK [../roles/barman_on_backup : Install Barman package] **********************
changed: [backup]

TASK [../roles/barman_on_backup : Update PATH - /etc/environment - not bug, just feature - for pg_receivexlog OK] ***
changed: [backup]

TASK [../roles/barman_on_backup : Update PATH - ~/.* - not bug, just feature - for pg_receivexlog OK] ***
changed: [backup]

TASK [../roles/barman_on_backup : Configure barman] ****************************
changed: [backup] => (item=/etc/barman.conf)
changed: [backup] => (item=/etc/barman.d/pg.conf)
changed: [backup] => (item=/var/lib/barman/.pgpass)
changed: [backup] => (item=/var/lib/barman/.ssh/)

TASK [../roles/barman_on_backup : Remote access check] *************************
changed: [backup] => (item=psql -c 'SELECT version()' -U barman -h 192.168.40.10 postgres)
changed: [backup] => (item=psql -U streaming_barman -h 192.168.40.10 -c "IDENTIFY_SYSTEM" replication=1)

TASK [../roles/barman_on_backup : Print remote access check result] ************
ok: [backup] => (item={'changed': True, 'end': '2025-02-19 17:54:25.120577', 'stdout': '                                                 version                                                 \n---------------------------------------------------------------------------------------------------------\n PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit\n(1 строка)', 'cmd': "psql -c 'SELECT version()' -U barman -h 192.168.40.10 postgres", 'rc': 0, 'start': '2025-02-19 17:53:21.859317', 'stderr': '', 'delta': '0:01:03.261260', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': "psql -c 'SELECT version()' -U barman -h 192.168.40.10 postgres", 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['                                                 version                                                 ', '---------------------------------------------------------------------------------------------------------', ' PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': "psql -c 'SELECT version()' -U barman -h 192.168.40.10 postgres", 'ansible_loop_var': 'item'}) => {
    "msg": "psql -c 'SELECT version()' -U barman -h 192.168.40.10 postgres => [RESULT] =>                                                  version                                                 \n---------------------------------------------------------------------------------------------------------\n PostgreSQL 13.5 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 4.8.5 20150623 (Red Hat 4.8.5-44), 64-bit\n(1 строка)"
}
ok: [backup] => (item={'changed': True, 'end': '2025-02-19 17:54:25.741531', 'stdout': '      systemid       | timeline |  xlogpos  | dbname \n---------------------+----------+-----------+--------\n 7033823135014916120 |        1 | 0/40000D8 | \n(1 строка)', 'cmd': 'psql -U streaming_barman -h 192.168.40.10 -c "IDENTIFY_SYSTEM" replication=1', 'rc': 0, 'start': '2025-02-19 17:54:25.710461', 'stderr': '', 'delta': '0:00:00.031070', 'invocation': {'module_args': {'creates': None, 'executable': None, '_uses_shell': True, 'strip_empty_ends': True, '_raw_params': 'psql -U streaming_barman -h 192.168.40.10 -c "IDENTIFY_SYSTEM" replication=1', 'removes': None, 'argv': None, 'warn': False, 'chdir': None, 'stdin_add_newline': True, 'stdin': None}}, 'stdout_lines': ['      systemid       | timeline |  xlogpos  | dbname ', '---------------------+----------+-----------+--------', ' 7033823135014916120 |        1 | 0/40000D8 | ', '(1 строка)'], 'stderr_lines': [], 'failed': False, 'item': 'psql -U streaming_barman -h 192.168.40.10 -c "IDENTIFY_SYSTEM" replication=1', 'ansible_loop_var': 'item'}) => {
    "msg": "psql -U streaming_barman -h 192.168.40.10 -c \"IDENTIFY_SYSTEM\" replication=1 => [RESULT] =>       systemid       | timeline |  xlogpos  | dbname \n---------------------+----------+-----------+--------\n 7033823135014916120 |        1 | 0/40000D8 | \n(1 строка)"
}

TASK [../roles/barman_on_backup : Create barman slot] **************************
changed: [backup]

TASK [../roles/barman_on_backup : Cron /usr/bin/barman backup] *****************
changed: [backup]

TASK [../roles/barman_on_backup : Cron /usr/bin/barman cron] *******************
changed: [backup]

TASK [../roles/barman_on_backup : barman check] ********************************
changed: [backup]

TASK [../roles/barman_on_backup : Store result of `barman check`] **************
fatal: [backup -> localhost]: FAILED! => {"msg": "The task includes an option with an undefined variable. The error was: 'dict object' has no attribute 'item'\n\nThe error appears to be in '/home/b/pycharm_projects_2025_2/otus_linux/040/ansible/roles/barman_on_backup/tasks/main.yml': line 347, column 3, but may\nbe elsewhere in the file depending on the exact syntax problem.\n\nThe offending line appears to be:\n\n\n- name: Store result of `barman check`\n  ^ here\n"}

PLAY RECAP *********************************************************************
backup                     : ok=14   changed=12   unreachable=0    failed=1    skipped=0    rescued=0    ignored=0   


```

</details>

Как видим выше, есть FAILED. 

НО!

Но стоит выполнить `barman cron` и их часть исчезнет, хотя при этом `barman cron` уже итак работает в `crontab` пользователя `barman`.


<details><summary>см. лог выполнения `barman cron`</summary>

```text
-- barman cron
Starting WAL archiving for server pg
```

</details>

Исчезнут 2 FAILED


<details><summary>см. лог выполнения `barman check pg`</summary>

```text
-- barman check pg
Server pg:
	PostgreSQL: OK
	superuser or standard user with backup privileges: OK
	PostgreSQL streaming: OK
	wal_level: OK
	replication slot: OK
	directories: OK
	retention policy settings: OK
	backup maximum age: OK (interval provided: 4 days, latest backup age: 2 minutes, 40 seconds)
	compression settings: OK
	failed backups: OK (there are 0 failed backups)
	minimum redundancy requirements: OK (have 3 backups, expected at least 1)
	pg_basebackup: OK
	pg_basebackup compatible: OK
	pg_basebackup supports tablespaces mapping: OK
	systemid coherence: OK
	pg_receivexlog: OK
	pg_receivexlog compatible: OK
	receive-wal running: OK
	archive_mode: OK
	archive_command: OK
	continuous archiving: OK
	archiver errors: OK
```

</details>


<details><summary>см. лог выполнения `barman backup pg`</summary>

```text
-- barman backup pg
Starting backup using postgres method for server pg in /var/lib/barman/pg/base/20250218T192421
Backup start at LSN: 0/C0000C8 (00000001000000000000000C, 000000C8)
Starting backup copy via pg_basebackup for 20250218T192421
Copy done (time: 11 seconds)
Finalising the backup.
Backup size: 24.1 MiB
Backup end at LSN: 0/E000060 (00000001000000000000000E, 00000060)
Backup completed (start time: 2025-02-19 19:24:21.732592, elapsed time: 13 seconds)
Processing xlog segments from streaming for pg
	00000001000000000000000C
	00000001000000000000000D
	00000001000000000000000E
Processing xlog segments from file archival for pg
	00000001000000000000000C
	00000001000000000000000D
	00000001000000000000000D.00000028.backup
```

</details>


<details><summary>см. лог выполнения `barman list-backup pg`</summary>

```text
-- barman list-backup pg
pg 20250218T192421 - Mon Nov 22 19:24:33 2025 - Size: 24.1 MiB - WAL Size: 0 B
pg 20250218T192106 - Mon Nov 22 19:21:38 2025 - Size: 24.1 MiB - WAL Size: 48.2 KiB
pg 20250218T191834 - Mon Nov 22 19:18:57 2025 - Size: 24.1 MiB - WAL Size: 48.2 KiB
pg 20250218T191709 - Mon Nov 22 19:17:16 2025 - Size: 24.1 MiB - WAL Size: 32.2 KiB - OBSOLETE
```

</details>

Исчезнут FAILED, связанные с бекапированием 


<details><summary>см. лог выполнения `barman check pg`</summary>

```text
barman_check_2['stdout']
```

</details>

Эти последние команды можно выполнить ролью 

```shell
ansible-playbook playbooks/barman_on_backup.yml --tags kick-barman > ../files/114_playbooks-barman_on_backup-kick_barman.yml.txt
```


<details><summary>см. лог выполнения `playbooks/barman_on_backup.yml --tags kick-barman`</summary>

```text

PLAY [Playbook of PostgreSQL barman on backup] *********************************

TASK [Gathering Facts] *********************************************************
ok: [backup]

TASK [../roles/barman_on_backup : kick barman] *********************************
changed: [backup] => (item=barman cron)
failed: [backup] (item=barman check pg) => {"ansible_loop_var": "item", "changed": true, "cmd": "barman check pg", "delta": "0:00:00.525761", "end": "2025-02-19 17:54:36.266778", "item": "barman check pg", "msg": "non-zero return code", "rc": 1, "start": "2025-02-19 17:54:35.741017", "stderr": "", "stderr_lines": [], "stdout": "Server pg:\n\tWAL archive: FAILED (please make sure WAL shipping is setup)\n\tPostgreSQL: OK\n\tsuperuser or standard user with backup privileges: OK\n\tPostgreSQL streaming: OK\n\twal_level: OK\n\treplication slot: OK\n\tdirectories: OK\n\tretention policy settings: OK\n\tbackup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)\n\tcompression settings: OK\n\tfailed backups: OK (there are 0 failed backups)\n\tminimum redundancy requirements: FAILED (have 0 backups, expected at least 1)\n\tpg_basebackup: OK\n\tpg_basebackup compatible: OK\n\tpg_basebackup supports tablespaces mapping: OK\n\tsystemid coherence: OK (no system Id stored on disk)\n\tpg_receivexlog: OK\n\tpg_receivexlog compatible: OK\n\treceive-wal running: OK\n\tarchive_mode: OK\n\tarchive_command: OK\n\tarchiver errors: OK", "stdout_lines": ["Server pg:", "\tWAL archive: FAILED (please make sure WAL shipping is setup)", "\tPostgreSQL: OK", "\tsuperuser or standard user with backup privileges: OK", "\tPostgreSQL streaming: OK", "\twal_level: OK", "\treplication slot: OK", "\tdirectories: OK", "\tretention policy settings: OK", "\tbackup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)", "\tcompression settings: OK", "\tfailed backups: OK (there are 0 failed backups)", "\tminimum redundancy requirements: FAILED (have 0 backups, expected at least 1)", "\tpg_basebackup: OK", "\tpg_basebackup compatible: OK", "\tpg_basebackup supports tablespaces mapping: OK", "\tsystemid coherence: OK (no system Id stored on disk)", "\tpg_receivexlog: OK", "\tpg_receivexlog compatible: OK", "\treceive-wal running: OK", "\tarchive_mode: OK", "\tarchive_command: OK", "\tarchiver errors: OK"]}
failed: [backup] (item=barman backup pg) => {"ansible_loop_var": "item", "changed": true, "cmd": "barman backup pg", "delta": "0:00:01.002586", "end": "2025-02-19 17:54:37.814281", "item": "barman backup pg", "msg": "non-zero return code", "rc": 1, "start": "2025-02-19 17:54:36.811695", "stderr": "ERROR: Impossible to start the backup. Check the log for more details, or run 'barman check pg'", "stderr_lines": ["ERROR: Impossible to start the backup. Check the log for more details, or run 'barman check pg'"], "stdout": "", "stdout_lines": []}
changed: [backup] => (item=barman list-backup pg)

PLAY RECAP *********************************************************************
backup                     : ok=1    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0   


```

</details>

Если перезапустить виртуалку, то опять понадобиться сделать `barman cron`. Это единственное, что я не могу понять, почему он не рабтает в службе или по крону. хотя лог запуска и там и там есть.


## Разный шлак мне на память, но не в ДЗ

```shell

cd ../../
cd ./040/vm/
vagrant destroy -f
vagrant up
python3 v2a.py -o ../ansible/inventories/hosts # Это уже как кредо
cd ../../
cd ./040/ansible/

ansible-playbook playbooks/master.yml --tags deploy > ../files/001_playbooks-master.yml.txt

ansible-playbook playbooks/replica.yml --tags deploy > ../files/002_playbooks-replica.yml.txt

ansible-playbook playbooks/replica_check_before.yml > ../files/003_playbooks-replica_check_before.yml.txt

ansible-playbook playbooks/master_check_and_activity.yml > ../files/004_playbooks-master_check_and_activity.yml.txt

ansible-playbook playbooks/replica_check_after.yml > ../files/005_playbooks-replica_check_after.yml.txt

ansible-playbook playbooks/barman_on_master.yml --tags feature-deploy > ../files/110_playbooks-barman_on_master.yml.txt

ansible-playbook playbooks/barman_on_backup.yml --tags feature-deploy > ../files/111_playbooks-barman_on_backup-feature_deploy.yml.txt

ansible-playbook playbooks/barman_on_backup.yml --tags kick-barman > ../files/114_playbooks-barman_on_backup-kick_barman.yml.txt








ansible-playbook playbooks/barman_on_master.yml --tags deploy > ../files/010_playbooks-barman_on_master.yml.txt

ansible-playbook playbooks/barman_on_backup.yml --tags install-postgresql > ../files/011_playbooks-barman_on_backup-install-postgresql.yml.txt

ansible-playbook playbooks/barman_on_backup.yml --tags install-and-configure-barman > ../files/012_playbooks-barman_on_backup-install-and-configure-barman.yml.txt

ansible-playbook playbooks/barman_on_backup.yml --tags barman-check > ../files/013_barman-check-001.txt

ansible-playbook playbooks/master_activity.yml > ../files/014_playbooks-master_activity.yml.txt

ansible-playbook playbooks/barman_on_backup.yml --tags barman-force-switch-wal > ../files/015_barman-force-switch-wal-001.txt

ansible-playbook playbooks/barman_on_backup.yml --tags barman-cron

ansible-playbook playbooks/barman_on_backup.yml --tags barman-force-switch-wal > ../files/016_barman-force-switch-wal-002.txt

ansible-playbook playbooks/barman_on_backup.yml --tags barman-check > ../files/017_barman-check-002.txt









* * * * * export PATH=$PATH:/usr/pgsql-9.6/bin; barman cron >/dev/null 2>&1





barman check pg

cd ../../
./details.py 040.details.md 0

cd ../../
cd ./040/vm/
vagrant destroy -f
vagrant up
python3 v2a.py -o ../ansible/inventories/hosts # Это уже как кредо
cd ../../
cd ./040/ansible/

ansible-playbook playbooks/master.yml --tags deploy
ansible-playbook playbooks/replica.yml --tags deploy

ansible-playbook playbooks/replica_check_before.yml 
ansible-playbook playbooks/master_check_and_activity.yml 
ansible-playbook playbooks/replica_check_after.yml

ansible-playbook playbooks/barman_on_master.yml --tags deploy
 
ansible-playbook playbooks/barman_on_backup.yml --tags install-postgresql-repo
ansible-playbook playbooks/barman_on_backup.yml --tags install-postgresql-server
ansible-playbook playbooks/barman_on_backup.yml --tags remote-access-check
 
ansible-playbook playbooks/barman_on_backup.yml --tags install-epel-repo 
ansible-playbook playbooks/barman_on_backup.yml --tags yum-barman-requirements 
ansible-playbook playbooks/barman_on_backup.yml --tags install-barman-package
ansible-playbook playbooks/barman_on_backup.yml --tags copy-config-files
ansible-playbook playbooks/barman_on_backup.yml --tags create-barman-slot
ansible-playbook playbooks/barman_on_backup.yml --tags add-path
ansible-playbook playbooks/barman_on_backup.yml --tags barman-cron-service
ansible-playbook playbooks/master_activity.yml # полезная нагрузка WAL
#ansible-playbook playbooks/barman_on_backup.yml --tags barman-switch-wal
ansible-playbook playbooks/barman_on_backup.yml --tags barman-force-switch-wal


psql postgresql://192.168.40.10:5432/postgres?sslmode=require
psql -H 192.168.40.10:5432 -U postgres -W

# su - postgres
# psql template1
# CREATE USER replication WITH PASSWORD 'replication';
# GRANT ALL PRIVILEGES ON DATABASE "postgres" to replication;
# GRANT ALL PRIVILEGES ON DATABASE "postgres" to 'replication';
CREATE USER replication REPLICATION LOGIN CONNECTION LIMIT 5 ENCRYPTED PASSWORD 'ident';"

sudo -u postgres psql
CREATE DATABASE test;
CREATE USER test WITH ENCRYPTED PASSWORD 'test';
GRANT ALL PRIVILEGES ON DATABASE test TO test;
psql -h 192.168.40.10 -U test -d test 


CREATE USER replication REPLICATION LOGIN CONNECTION LIMIT 5 ENCRYPTED PASSWORD 'replication';"

ошибка: не удалось подключиться к серверу: Нет маршрута до узла
        Он действительно работает по адресу "192.168.40.10"
         и принимает TCP-соединения (порт 5432)?

netstat -nlp | grep 5432

systemctl stop postgresql-11
systemctl start postgresql-11
sudo service postgresql-11 restart

psql -h 192.168.40.10 -U replication -d replication -W
psql -h 192.168.40.10 -U test -d test -W

lsof -i | grep 'post'

Тогда вы можете узнать, какой порт слушает.
psql -U postgres -p "port_in_use"

ansible-playbook playbooks/master.yml   --tags collect-pg.conf-files
ansible-playbook playbooks/replica.yml  --tags collect-pg.conf-files
ansible-playbook playbooks/master.yml   --tags deploy
ansible-playbook playbooks/replica.yml  --tags install-epel-repo
ansible-playbook playbooks/replica.yml  --tags install-postgresql
ansible-playbook playbooks/replica.yml  --tags create-postgresql-data-dir
ansible-playbook playbooks/replica.yml  --tags install-python3-pip
ansible-playbook playbooks/replica.yml  --tags install-python3-pexpect
ansible-playbook playbooks/replica.yml  --tags copy-master-data
ansible-playbook playbooks/master.yml   --tags collect-pg.conf-files


SELECT datname FROM pg_database;
SELECT schema_name FROM information_schema.schemata;
SELECT schemaname, tablename FROM pg_catalog.pg_tables;
SELECT * FROM public.testtable;
\c test 

```

## Заместки

* pexpect==3.3 - очень важно именно такая версия, так как в репе 2.*
* generic/centos7 - плохой дистрибутив для реплицирования PostgreSQL, что-то с недоступностью по 5432




ansible-playbook playbooks/barman_on_backup.yml --tags deploy
ansible-playbook playbooks/barman_on_backup.yml --tags step-001
ansible-playbook playbooks/barman_on_backup.yml --tags precheck-barman
ansible-playbook playbooks/barman_on_backup.yml --tags precheck-replicator-barman
ansible-playbook playbooks/barman_on_backup.yml --tags install-barman
ansible-playbook playbooks/barman_on_backup.yml --tags configure-barman
ansible-playbook playbooks/barman_on_backup.yml --tags copy-config-files
ansible-playbook playbooks/barman_on_master.yml
ansible-playbook playbooks/barman_on_backup.yml --tags copy-config-files
precheck_replicator_barman



su - barman
barman receive-wal --create-slot pg
barman switch-wal --force --archive pg
barman check pg
yum repolist
yum repolist enabled

yum --disablerepo="*" --enablerepo='2ndquadrant-dl-default-release-pg11/7/x86_64' install barman

 yum install postgresql11-libs.x86_64


Actually the given URL also says in the System requirements section:

    Linux/Unix
    Python >= 3.4
    Python modules:
        argcomplete
        argh >= 0.21.2
        psycopg2 >= 2.4.2
        python-dateutil
        setuptools
    PostgreSQL >= 8.3
    rsync >= 3.0.4 (optional for PostgreSQL >= 9.2)

barman cron

ssh -o "StrictHostKeyChecking no" postgres@192.168.40.10


sudo yum -y install barman
yum provides audit2allow

yum install policycoreutils-python

 sudo audit2allow -a
* * * * * echo $(date '+%Y-%m-%d') >> /var/lib/barman/1.txt

#============= sshd_t ==============
allow sshd_t postgresql_db_t:file read;

sudo audit2allow -a -M pg_ssh
sudo  semodule -i  pg_ssh.pp

#!!!! The file '/var/lib/pgsql/.ssh/authorized_keys' is mislabeled on your system.  
#!!!! Fix with $ restorecon -R -v /var/lib/pgsql/.ssh/authorized_keys
allow sshd_t postgresql_db_t:file open;

#!!!! This avc is allowed in the current policy
allow sshd_t postgresql_db_t:file read;

#!!!! The file '/var/lib/pgsql/.ssh/authorized_keys' is mislabeled on your system.  
#!!!! Fix with $ restorecon -R -v /var/lib/pgsql/.ssh/authorized_keys
allow sshd_t postgresql_db_t:file getattr;

#!!!! This avc is allowed in the current policy
allow sshd_t postgresql_db_t:file { open read };
[vagrant@master ~]$ sudo audit2allow -a -M pg_ssh


barman cron
* * * * * export PATH=$PATH:/usr/pgsql-9.6/bin; barman cron >/dev/null 2>&1

 sudo su - barman
Last login: Вт окт 26 19:42:21 UTC 2025 on pts/0
-bash-4.2$ barman cron

barman backup pg --wait

 sudo su - postgres
-bash-4.2$ psql
psql (11.13)
Type "help" for help.

postgres=# select * from pg_replication_slots;
      slot_name      | plugin | slot_type | datoid | database | temporary | active | active_pid | xmin | catalog_xmin | restart_lsn | confirmed_flush_lsn 
---------------------+--------+-----------+--------+----------+-----------+--------+------------+------+--------------+-------------+---------------------
 pg_slot_replication |        | physical  |        |          | f         | t      |      21626 |      |              | 0/B01FA90   | 
(1 row)

* * * * * export PATH=$PATH:/usr/pgsql-11/bin; barman cron >/dev/null 2>&1
barman switch-xlog --force --archive
------------------

   66  export PATH=$PATH:/usr/pgsql-11/bin/
   67  echo $PATH
   68  barman receive-wal pg
   69  barman check pg
   70  barman switch-wal --force --archive pg
   71  barman receive-wal pg
   72  barman switch-xlog --force --archive
   73  barman switch-xlog --force --archive pg
   74  barman check pg
   75  history


30 23 * * * /usr/bin/barman backup clust_dvdrental

systemctl status barman-cron
systemctl enable barman-cron.service
systemctl status barman-cron.service
systemctl status barman-cron.timer
systemctl stop barman-cron.timer
systemctl start barman-cron.timer
 sudo journalctl -u  barman-cron


 sudo su - barman
barman receive-wal --create-slot pg
barman cron
barman switch-wal --force --archive pg
barman backup pg
barman check pg
barman switch-wal pg

yum repolist
yum repolist enabled



barman show-server pg
barman check pg

barman backup pg &

 barman list-backup pg
pg 20250218T211728 - STARTED


2025-02-19 21:17:28,604 [22577] barman.backup_executor INFO: Starting backup copy via pg_basebackup for 20250219T211728
2025-02-19 21:17:28,959 [22086] barman.command_wrappers INFO: pg: pg_receivewal: finished segment at 0/13000000 (timeline 1)
2025-02-19 21:17:29,751 [22086] barman.command_wrappers INFO: pg: pg_receivewal: finished segment at 0/14000000 (timeline 1)
2025-02-19 21:18:02,705 [22591] barman.wal_archiver INFO: Found 2 xlog segments from streaming for pg. Archive all segments in one run.
2025-02-19 21:18:02,705 [22591] barman.wal_archiver INFO: Archiving segment 1 of 2 from streaming: pg/000000010000000000000012
2025-02-19 21:18:02,717 [22592] barman.server INFO: Another archive-wal process is already running on server pg. Skipping to the next server
2025-02-19 21:18:02,957 [22591] barman.wal_archiver INFO: Archiving segment 2 of 2 from streaming: pg/000000010000000000000013
2025-02-19 21:19:01,767 [22602] barman.wal_archiver INFO: No xlog segments found from streaming for pg.
2025-02-19 21:20:02,164 [22613] barman.wal_archiver INFO: No xlog segments found from streaming for pg.
2025-02-19 21:21:03,596 [22626] barman.wal_archiver INFO: No xlog segments found from streaming for pg.


barman backps aux | grep backup
barman   22893  0.5  8.1 263540 19696 pts/0    S    21:41   0:00 /usr/bin/python2 /bin/barman backup pg
barman   22896  0.7  1.6 180800  3860 pts/0    S    21:41   0:00 /bin/pg_basebackup --dbname=dbname=replication host=192.168.40.10 options=-cdatestyle=iso replication=true user=streaming_barman application_name=barman_streaming_backup -v --no-password --pgdata=/var/lib/barman/pg/base/20250219T214107/data --no-slot --wal-method=none --checkpoint=fast


barman list-server
ansible-playbook playbooks/master.yml --tags deploy > ../files/001_playbooks-master.yml.txt
```
