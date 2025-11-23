# Механизм блокировок

## Цель:

понимать как работает механизм блокировок объектов и строк.

## План

1. Настройте сервер так, чтобы в журнал сообщений сбрасывалась информация о блокировках, удерживаемых более 200 миллисекунд. Воспроизведите ситуацию, при которой в журнале появятся такие сообщения.
2. Смоделируйте ситуацию обновления одной и той же строки тремя командами UPDATE в разных сеансах. Изучите возникшие блокировки в представлении pg_locks и убедитесь, что все они понятны. Пришлите список блокировок и объясните, что значит каждая.
3. Воспроизведите взаимоблокировку трех транзакций. Можно ли разобраться в ситуации постфактум, изучая журнал сообщений?
4. Могут ли две транзакции, выполняющие единственную команду UPDATE одной и той же таблицы (без where), заблокировать друг друга?



## Выполнение

> [!NOTE]
> Для выполнения этого ДЗ пользуемся кластером в 15. Остальние кластера на ВМ, как обычно, будут отключены. 

Соответственно отключаем в.17 и в.14:
```sh
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@17-main
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@14-main
aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 down   postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
17  main    5432 online postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log
```


### 1. Настройте сервер так, чтобы в журнал сообщений сбрасывалась информация о блокировках, удерживаемых более 200 миллисекунд. Воспроизведите ситуацию, при которой в журнале появятся такие сообщения.

Проверим, какие настройики помогут нам получить информацию о блокировках:

```sql
postgres=# select name , setting, unit from pg_settings
where name like '%lock%';
              name              | setting | unit
--------------------------------+---------+------
 block_size                     | 8192    |
 deadlock_timeout               | 1000    | ms
 lock_timeout                   | 0       | ms
 log_lock_waits                 | off     |
 max_locks_per_transaction      | 64      |
 max_pred_locks_per_page        | 2       |
 max_pred_locks_per_relation    | -2      |
 max_pred_locks_per_transaction | 64      |
 wal_block_size                 | 8192    |
(9 rows)
```

Меняем deadlock_timeout и log_lock_waits таким образом

> [!NOTE]
> По ошибке поставил значение 100ms вместо 200ms, но для выполнения задач нет никакой разницы. 

```sql
postgres=# alter system set deadlock_timeout='100ms';
ALTER SYSTEM
postgres=# alter system set log_lock_waits=on;
ALTER SYSTEM
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 row)
```

Проверим в лог-файле, что новые настройки применены:
```sh
2025-11-20 17:45:03.345 UTC [1051] LOG:  received SIGHUP, reloading configuration files
2025-11-20 17:45:03.347 UTC [1051] LOG:  parameter "deadlock_timeout" changed to "100ms"
2025-11-20 17:45:03.347 UTC [1051] LOG:  parameter "log_lock_waits" changed to "on"
```

Для воспроизведения ситуации блокировки, пользуемся таблицей TEST в нашем кластере в.15:
```sql
postgres=# select * from test;
 c1
----
 1
(1 row)


> [!WARNING]
> Для этого первого теста включен *autocommit*, однако мы его отключим в пункте 3.

Запускаем первый лок в виде *select for update* :
1st_session=# begin;
BEGIN
1st_session=*# select * from test where c1 = '3' for update;
 c1
----
 3
(1 row)

1st_session=*# 
```

Во втором сеансе запускаем *update*. 
```sql
2nd_session=# update test set c1='2' where c1='3';
<<<...>>>
```

Здесь BEGIN или отключение автокоммита не потребуется так как запрос сразу висит в ожидании получения *ShareLock* как видно в логе:
```sh
2025-11-20 17:54:44.936 UTC [1795] postgres@postgres LOG:  process 1795 still waiting for ShareLock on transaction 4545163 after 100.563 ms
2025-11-20 17:54:44.936 UTC [1795] postgres@postgres DETAIL:  Process holding the lock: 1737. Wait queue: 1795.
2025-11-20 17:54:44.936 UTC [1795] postgres@postgres CONTEXT:  while updating tuple (0,3) in relation "test"
2025-11-20 17:54:44.936 UTC [1795] postgres@postgres STATEMENT:  update test set c1='2' where c1='3';
```

В первом сеансе завершаем транзакцию:
```sql
1nd_session=*# end;
COMMIT
```

Мгновенно выполняется запрос во втором сеансе:
```sql
2nd_session=# update test set c1='2' where c1='3';
UPDATE 1
```

```sh
2025-11-20 17:55:37.888 UTC [1795] postgres@postgres LOG:  process 1795 acquired ShareLock on transaction 4545163 after 53052.348 ms
2025-11-20 17:55:37.888 UTC [1795] postgres@postgres CONTEXT:  while updating tuple (0,3) in relation "test"
2025-11-20 17:55:37.888 UTC [1795] postgres@postgres STATEMENT:  update test set c1='2' where c1='3';
```



### 2. Смоделируйте ситуацию обновления одной и той же строки тремя командами UPDATE в разных сеансах. Изучите возникшие блокировки в представлении pg_locks и убедитесь, что все они понятны. Пришлите список блокировок и объясните, что значит каждая.


> [!NOTE]
> *autocommit* отключен.

Запускаем 3 разных запросов в разных сеансах:
```sql
1nd_session=*# update test set c1='first_update' where c1 = '2';
UPDATE 1
1nd_session=*# 
```

```sql
2nd_session=# update test set c1='second_update' where c1 = '2';
<<<...>>>
```

```sql
3rd_session=# update test set c1='third_update' where c1 = '2';
<<<...>>>
```

С помощью *pg_locks* проверим, какие блокировки существуют между этими сеансами:
```sql
postgres=# SELECT locktype, relation::REGCLASS, mode, granted, pid, pg_blocking_pids(pid) AS wait_for
FROM pg_locks WHERE relation = 'test'::regclass order by pid;
 locktype | relation |       mode       | granted |  pid  | wait_for
----------+----------+------------------+---------+-------+----------
 relation | test     | AccessShareLock  | t       |  1737 | {}
 relation | test     | RowExclusiveLock | t       |  1737 | {}
 relation | test     | RowExclusiveLock | t       |  1795 | {1737}
 tuple    | test     | ExclusiveLock    | t       |  1795 | {1737}
 relation | test     | RowExclusiveLock | t       | 12982 | {1795}
 tuple    | test     | ExclusiveLock    | f       | 12982 | {1795}
(6 rows)
```


### 3. Воспроизведите взаимоблокировку трех транзакций. Можно ли разобраться в ситуации постфактум, изучая журнал сообщений?

изучая журнал сообщений, можно без проблем понимать последовательность блокировок.
```sql
2025-11-20 18:09:28.681 UTC [1795] postgres@postgres LOG:  process 1795 still waiting for ShareLock on transaction 4545165 after 100.189 ms
2025-11-20 18:09:28.681 UTC [1795] postgres@postgres DETAIL:  Process holding the lock: 1737. Wait queue: 1795.
2025-11-20 18:09:28.681 UTC [1795] postgres@postgres CONTEXT:  while updating tuple (0,4) in relation "test"
2025-11-20 18:09:28.681 UTC [1795] postgres@postgres STATEMENT:  update test set c1='second_update' where c1 = '2';
[...]
2025-11-20 18:09:44.643 UTC [12982] postgres@postgres LOG:  process 12982 still waiting for ExclusiveLock on tuple (0,4) of relation 16388 of database 5 after 100.246 ms
2025-11-20 18:09:44.643 UTC [12982] postgres@postgres DETAIL:  Process holding the lock: 1795. Wait queue: 12982.
2025-11-20 18:09:44.643 UTC [12982] postgres@postgres STATEMENT:  update test set c1='third_update' where c1 = '2';
```

В данном случае можно по крайней мере перестроить такой вид:

{12982 - ExclusiveLock (waiting) [test (0,4)]} --> {1795 - ExclusiveLock (granted) [test (0,4)]} --> {1737 - ShareLock}

Закомитим первый сеанс: 
```sql
1nd_session=*# commit;
COMMIT
```

Во втором сеансе запрос выполняется:
```sql
2nd_session=# update test set c1='second_update' where c1 = '2';
UPDATE 0
```

Сразу появляются сообщения о том, что последовательность блокировок изменилась следуючим образом:
```sh
postgres=# 2025-11-20 18:22:43.532 UTC [1795] postgres@postgres LOG:  process 1795 acquired ShareLock on transaction 4545165 after 794950.509 ms
2025-11-20 18:22:43.532 UTC [1795] postgres@postgres CONTEXT:  while updating tuple (0,4) in relation "test"
2025-11-20 18:22:43.532 UTC [1795] postgres@postgres STATEMENT:  update test set c1='second_update' where c1 = '2';
2025-11-20 18:22:43.532 UTC [12982] postgres@postgres LOG:  process 12982 acquired ExclusiveLock on tuple (0,4) of relation 16388 of database 5 after 778989.435 ms

2025-11-20 18:22:43.532 UTC [12982] postgres@postgres STATEMENT:  update test set c1='third_update' where c1 = '2';
2025-11-20 18:22:43.634 UTC [12982] postgres@postgres LOG:  process 12982 still waiting for ShareLock on transaction 4545166 after 101.380 ms
2025-11-20 18:22:43.634 UTC [12982] postgres@postgres DETAIL:  Process holding the lock: 1795. Wait queue: 12982.
2025-11-20 18:22:43.634 UTC [12982] postgres@postgres CONTEXT:  while locking tuple (0,5) in relation "test"
2025-11-20 18:22:43.634 UTC [12982] postgres@postgres STATEMENT:  update test set c1='third_update' where c1 = '2';
```

Ситуация теиерь такая:
{12982 - ExclusiveLock (granted) [test (0,4)]} --> {1795 - ShareLock}

Закомитим 2-й сеанс:
```sql
2nd_session=*# commit;
COMMIT
```

в 3-й сеанс выполняется запрос после получения *sharedlock*
```sql
3rd_session=# update test set c1='third_update' where c1 = '2';
UPDATE 0
```

В логе видно, что блокировок больше нет:
```sh
postgres=# 2025-11-20 18:24:52.838 UTC [12982] postgres@postgres LOG:  process 12982 acquired ShareLock on transaction 4545166 after 129305.363 ms
2025-11-20 18:24:52.838 UTC [12982] postgres@postgres CONTEXT:  while locking tuple (0,5) in relation "test"
2025-11-20 18:24:52.838 UTC [12982] postgres@postgres STATEMENT:  update test set c1='third_update' where c1 = '2';
```

Завершаем эксперимент:
```sql
3rd_session=*# commit;
COMMIT
```


### 4. Могут ли две транзакции, выполняющие единственную команду UPDATE одной и той же таблицы (без where), заблокировать друг друга?

При выполнения единственной команды UPDATE одной и той же таблицы (без where), мы получаем такую последователбность: 

```sql
postgres=# 2025-11-20 18:28:46.873 UTC [12982] postgres@postgres LOG:  process 12982 still waiting for ShareLock on transaction 4545168 after 101.984 ms
2025-11-20 18:28:46.873 UTC [12982] postgres@postgres DETAIL:  Process holding the lock: 1795. Wait queue: 12982.
2025-11-20 18:28:46.873 UTC [12982] postgres@postgres CONTEXT:  while updating tuple (0,5) in relation "test"
2025-11-20 18:28:46.873 UTC [12982] postgres@postgres STATEMENT:  update test set c1='no where';
```

```sql
FROM pg_locks WHERE relation = 'test'::regclass order by pid;
 locktype | relation |       mode       | granted |  pid  | wait_for
----------+----------+------------------+---------+-------+----------
 relation | test     | AccessShareLock  | t       |  1795 | {}
 relation | test     | RowExclusiveLock | t       |  1795 | {}
 relation | test     | RowExclusiveLock | t       | 12982 | {1795}
 tuple    | test     | ExclusiveLock    | t       | 12982 | {1795}
(4 rows)
```

Здесь видно, что ничего не блокирует сеанс *1795*. Поэтому без участия другово DML в сеансе *12982*, которое бы предотвратило получение блокировки сеансом *1795*, такая ситуация выглядит невозможна.
