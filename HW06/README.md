# Настройка autovacuum с учетом особеностей производительности


## Цель

- запустить нагрузочный тест pgbench
- настроить параметры autovacuum
- проверить работу autovacuum

## План

1. Создать инстанс ВМ с 2 ядрами и 4 Гб ОЗУ и SSD 10GB
2. Установить на него PostgreSQL 15 с дефолтными настройками
3. Создать БД для тестов: выполнить pgbench -i postgres
4. Запустить pgbench -c8 -P 6 -T 60 -U postgres postgres
5. Применить параметры настройки PostgreSQL из прикрепленного к материалам занятия файла
6. Протестировать заново
7. Что изменилось и почему?
8. Создать таблицу с текстовым полем и заполнить случайными или сгенерированными данным в размере 1млн строк
9. Посмотреть размер файла с таблицей
10. 5 раз обновить все строчки и добавить к каждой строчке любой символ
11. Посмотреть количество мертвых строчек в таблице и когда последний раз приходил автовакуум
12. Подождать некоторое время, проверяя, пришел ли автовакуум
13. 5 раз обновить все строчки и добавить к каждой строчке любой символ
14. Посмотреть размер файла с таблицей
15. Отключить Автовакуум на конкретной таблице
16. 10 раз обновить все строчки и добавить к каждой строчке любой символ
17. Посмотреть размер файла с таблицей
18. Объясните полученный результат
19. Не забудьте включить автовакуум)

> [!NOTE]
> Задание со *:
> Написать анонимную процедуру, в которой в цикле 10 раз обновятся все строчки в искомой таблице.
> Не забыть вывести номер шага цикла.



## Выполнение


### 1. Создать инстанс ВМ с 2 ядрами и 4 Гб ОЗУ и SSD 10GB

Снова используем машину, созданную в рамках предыдущего ДЗ.
Для этого ДЗ она будет настроена вот таким образом:

```sh
aduron@ubt-pg-aduron:~$ cat /proc/cpuinfo  | grep process| wc -l
2
aduron@ubt-pg-aduron:~$ free
               total        used        free      shared  buff/cache   available
Mem:         4009960      470788     3269920       14280      505268     3539172
Swap:              0           0           0
             0           0           0
```

### 2. Установить на него PostgreSQL 15 с дефолтными настройками

На этой машине у нас уже развернуты различные кластера.

```sh
aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 online postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
17  main    5432 online postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log
```

Соответственно отключаем в.14 и в.17 так как ДЗ упоминает в.15.
```sh
aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
[sudo] password for aduron:
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 online postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
17  main    5432 online postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@14-main
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@17-main
aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 online postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
17  main    5432 down   postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log
```

Также, вернём кластер в.15 к настроикам по умольчанию, с помощью следующих команд:
```sql
aduron@ubt-pg-aduron:~$ sudo su - postgres
[sudo] password for aduron:
postgres@ubt-pg-aduron:~$ psql -p 5433
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
Type "help" for help.

postgres=# alter system reset all;
ALTER SYSTEM
postgres=# exit

aduron@ubt-pg-aduron:~$ sudo systemctl restart postgresql@15-main
```



### 3. Создать БД для тестов: выполнить pgbench -i postgres

Запускаем процесс инициализации:
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -i
Password:
dropping old tables...
creating tables...
generating data (client-side)...
vacuuming...
creating primary keys...
done in 0.19 s (drop tables 0.01 s, create tables 0.02 s, client-side generate 0.08 s, vacuum 0.04 s, primary keys 0.04 s).
```


### 4. Запустить pgbench -c 8 -P 6 -T 60 -U postgres postgres


Далее запускаем первый тест производительности с дефольтними настроиками:
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 8 -P 6 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 6.0 s, 927.0 tps, lat 8.435 ms stddev 5.265, 0 failed
progress: 12.0 s, 964.7 tps, lat 8.286 ms stddev 5.033, 0 failed
progress: 18.0 s, 1280.0 tps, lat 6.246 ms stddev 4.593, 0 failed
progress: 24.0 s, 1612.6 tps, lat 4.956 ms stddev 3.090, 0 failed
progress: 30.0 s, 1565.3 tps, lat 5.101 ms stddev 3.334, 0 failed
progress: 36.0 s, 1418.0 tps, lat 5.640 ms stddev 4.279, 0 failed
progress: 42.0 s, 1559.3 tps, lat 5.125 ms stddev 3.339, 0 failed
progress: 48.0 s, 1499.0 tps, lat 5.331 ms stddev 3.408, 0 failed
progress: 54.0 s, 1403.5 tps, lat 5.696 ms stddev 4.321, 0 failed
progress: 60.0 s, 1571.8 tps, lat 5.084 ms stddev 3.351, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 82816
number of failed transactions: 0 (0.000%)
latency average = 5.779 ms
latency stddev = 4.091 ms
initial connection time = 122.995 ms
tps = 1382.749901 (without initial connection time)
```


### 5. Применить параметры настройки PostgreSQL из прикрепленного к материалам занятия файла

Значение каждой настройки завизит от единицы, преобразования написаны в комментариях.  
Соответсвенно запускаем *alter system* для каждой.
```sql
-- max_connections = 40
-- shared_buffers = 1GB  (Unit: 8kB - 1024*1024/8 = 131072)
-- effective_cache_size = 3GB  (Unit: 8kB - 3*1024*1024/8 = 393216)
-- maintenance_work_mem = 512MB (Unit: kB - 512*1024 = 524288)
-- checkpoint_completion_target = 0.9;
-- wal_buffers = 16MB (Unit: 8kB - 16*1024/8 = 2048)
-- default_statistics_target = 500;
-- random_page_cost = 4;
-- effective_io_concurrency = 2;
-- work_mem = 6553kB (Unit: kB)
-- min_wal_size = 4GB (Unit: MB - 4*1024 = 4096)
-- max_wal_size = 16GB (Unit: MB - 16*1024 = 16384) 

alter system set max_connections = 40;
ALTER SYSTEM
alter system set shared_buffers = 131072;
ALTER SYSTEM
alter system set effective_cache_size = 393216;
ALTER SYSTEM
alter system set maintenance_work_mem = 524288;
ALTER SYSTEM
alter system set checkpoint_completion_target = 0.9;
ALTER SYSTEM
alter system set wal_buffers = 2048;
ALTER SYSTEM
alter system set default_statistics_target = 500;
ALTER SYSTEM
alter system set random_page_cost = 4;
ALTER SYSTEM
alter system set effective_io_concurrency = 2;
ALTER SYSTEM
alter system set work_mem = 6553;
ALTER SYSTEM
alter system set min_wal_size = 4096;
ALTER SYSTEM
alter system set max_wal_size = 16384;
ALTER SYSTEM
```

И *systemctl restart* для учета настроек, требующих перезагрузки
```sh
aduron@ubt-pg-aduron:~$ sudo systemctl restart postgresql@15-main
```

### 6. Протестировать заново

После изменения запускаем тест повторно.
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 8 -P 6 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 6.0 s, 1007.5 tps, lat 7.757 ms stddev 4.642, 0 failed
progress: 12.0 s, 1014.9 tps, lat 7.873 ms stddev 4.859, 0 failed
progress: 18.0 s, 1554.3 tps, lat 5.143 ms stddev 3.211, 0 failed
progress: 24.0 s, 1565.7 tps, lat 5.105 ms stddev 3.194, 0 failed
progress: 30.0 s, 1584.8 tps, lat 5.044 ms stddev 3.286, 0 failed
progress: 36.0 s, 1433.6 tps, lat 5.575 ms stddev 4.329, 0 failed
progress: 42.0 s, 1625.5 tps, lat 4.916 ms stddev 3.142, 0 failed
progress: 48.0 s, 1564.5 tps, lat 5.107 ms stddev 3.324, 0 failed
progress: 54.0 s, 1476.0 tps, lat 5.416 ms stddev 3.950, 0 failed
progress: 60.0 s, 1571.5 tps, lat 5.086 ms stddev 3.245, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 86397
number of failed transactions: 0 (0.000%)
latency average = 5.539 ms
latency stddev = 3.794 ms
initial connection time = 128.397 ms
tps = 1442.645318 (without initial connection time)
```


### 7. Что изменилось и почему?

Видим что больших улучшении производительности нет (всего лишь 3 процента, что не удивительно так как мы в предыдущее ДЗ заметили что улучения касается в большинстве настройки *fsync*, которой мы не трогали в пункте 5)


### 8. Создать таблицу с текстовым полем и заполнить случайными или сгенерированными данным в размере 1млн строк


```sql
postgres=# create table test_table as
select
        generate_series(1,1000000) AS id,
        md5(random()::text) AS random_text
;
SELECT 1000000
postgres=# \d
              List of relations
 Schema |       Name       | Type  |  Owner
--------+------------------+-------+----------
 public | pgbench_accounts | table | postgres
 public | pgbench_branches | table | postgres
 public | pgbench_history  | table | postgres
 public | pgbench_tellers  | table | postgres
 public | test             | table | postgres
 public | test_table       | table | postgres

postgres=# \d test_table
               Table "public.test_table"
   Column    |  Type   | Collation | Nullable | Default
-------------+---------+-----------+----------+---------
 id          | integer |           |          |
 random_text | text    |           |          |
```



### 9. Посмотреть размер файла с таблицей


Проверить размер файла можно различными способами:

```sql
postgres=# show data_directory;
  data_directory
-------------------
 /mnt/data/15/main
(1 row)

postgres=# select datname, oid from pg_database where datname='postgres';
\ datname  | oid
----------+-----
 postgres |   5
(1 row)

-- найдя oid файла 
postgres=# select relname, oid, relfilenode from pg_class where relname='test_table';
  relname   |  oid  | relfilenode
------------+-------+-------------
 test_table | 16523 |       16523

-- или c pg_relation_filepath
postgres=#  SELECT pg_relation_filepath('test_table');
 pg_relation_filepath
----------------------
 base/5/16523

-- в итоге рамер узнаем либо с командой ls ...
root@ubt-pg-aduron:~# ls -lrt /mnt/data/15/main/base/5/16523*
-rw------- 1 postgres postgres     8192 Nov 11 18:17 /mnt/data/15/main/base/5/16523_vm
-rw------- 1 postgres postgres    40960 Nov 11 18:17 /mnt/data/15/main/base/5/16523_fsm
-rw------- 1 postgres postgres 68272128 Nov 11 18:21 /mnt/data/15/main/base/5/16523

-- ... либо с pg_size_pretty
postgres=# SELECT pg_size_pretty(pg_total_relation_size('test_table'));
 pg_size_pretty
----------------
 65 MB
(1 row)

-- Также можно запустить этот ужасный (зато интересный) запрос:
postgres=# SELECT l.metric, l.nr AS bytes
     , CASE WHEN is_size THEN pg_size_pretty(nr) END AS bytes_pretty
     , CASE WHEN is_size THEN nr / NULLIF(x.ct, 0) END AS bytes_per_row
FROM  (
   SELECT min(tableoid)        AS tbl      -- = 'public.tbl'::regclass::oid
        , count(*)             AS ct
        , sum(length(t::text)) AS txt_len  -- length in characters
   FROM   public.test_table t              -- provide table name *once*
   ) x
CROSS  JOIN LATERAL (
   VALUES
     (true , 'core_relation_size'               , pg_relation_size(tbl))
   , (true , 'visibility_map'                   , pg_relation_size(tbl, 'vm'))
   , (true , 'free_space_map'                   , pg_relation_size(tbl, 'fsm'))
   , (true , 'table_size_incl_toast'            , pg_table_size(tbl))
   , (true , 'indexes_size'                     , pg_indexes_size(tbl))
   , (true , 'total_size_incl_toast_and_indexes', pg_total_relation_size(tbl))
   , (true , 'live_rows_in_text_representation' , txt_len)
   , (false, '------------------------------'   , NULL)
   , (false, 'row_count'                        , ct)
   , (false, 'live_tuples'                      , pg_stat_get_live_tuples(tbl))
   , (false, 'dead_tuples'                      , pg_stat_get_dead_tuples(tbl))
   ) l(is_size, metric, nr);
              metric               |  bytes   | bytes_pretty | bytes_per_row
-----------------------------------+----------+--------------+---------------
 core_relation_size                | 68272128 | 65 MB        |            68
 visibility_map                    |     8192 | 8192 bytes   |             0
 free_space_map                    |    40960 | 40 kB        |             0
 table_size_incl_toast             | 68329472 | 65 MB        |            68
 indexes_size                      |        0 | 0 bytes      |             0
 total_size_incl_toast_and_indexes | 68329472 | 65 MB        |            68
 live_rows_in_text_representation  | 40888896 | 39 MB        |            40 
 ------------------------------    |          |              |
 row_count                         |  1000000 |              |
 live_tuples                       |  1000000 |              |
 dead_tuples                       |        0 |              |
(11 rows)
```

Размер файла 65МБ.
Из интересного здесь видно *данные* (преобразованные как текст) занимают всего лишь 40мБ.
Это значение можно подтвердить вот так


```sql
postgres=# SELECT length(array_to_string(array(SELECT id::text || random_text::text FROM test_table2),',')) limit 1;
  length
----------
 38888895
```

Разница объясняется тем, что существуют допольнительные мета-данные, в частности:

*HeapTupleHeader (23 bytes): Every row (or "tuple") in a PostgreSQL table has a fixed-size header, which occupies 23 bytes on most 64-bit systems. This header contains essential metadata about the row, such as transaction IDs (xmin, xmax), command IDs (cmin, cmax), and flags (t_infomask, t_infomask2). This overhead is present for every row, regardless of the actual user data it contains.*

![VM](img/dz6-1.png)


*Item Identifier (4 bytes): Each row within a page also has an item identifier (or "line pointer") in the page header, which points to the location of the tuple within the page. This adds 4 bytes of overhead per row within the page structure.*

... и также мелочи как *Page Overhead*, *Null Bitmap*, и прочие.

в данном случае, это добавляет (27*1000000)/1024/1024) = 25.74 МБ.
Итоговый размер польностю совпадает с *core_relation_size*


### 10. 5 раз обновить все строчки и добавить к каждой строчке любой символ

Добавить рандомный символ можно вот таким образом:
```sql
postgres=# select random_text, random_text||substr(md5(random()::text), 1, 1) as random_text_plus_chr from
 test_table limit 5
;
           random_text            |       random_text_plus_chr
----------------------------------+-----------------------------------
 ece71813c8fa789af0a30a3dd7ae3e4d | ece71813c8fa789af0a30a3dd7ae3e4d5
 8164528b4cffbf56d750c04bc57a1109 | 8164528b4cffbf56d750c04bc57a11096
 8c7d0dece85a0554fa62bffbf3c4c747 | 8c7d0dece85a0554fa62bffbf3c4c7479
 a825f856313f029b3194ddde570f288b | a825f856313f029b3194ddde570f288be
 88851e1976ac5d84849992d86986d387 | 88851e1976ac5d84849992d86986d3874
(5 rows)
```

Update будет в данном случае выглядить вот так...
```sql
update test_table set random_text = random_text||substr(md5(random()::text), 1, 1);
```

... но мы можем его запустить 5 раз подряд таким способом (это не процедура, но это лучше хехе):
```sql
select $$update test_table set random_text = random_text||substr(md5(random()::text), 1, 1); $$ from generate_series(1,5) \gexec

postgres=# select $$update test_table set random_text = random_text||substr(md5(random()::text), 1, 1); $$ from generate_series(1,5) \gexec
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
```


### 11. Посмотреть количество мертвых строчек в таблице и когда последний раз приходил автовакуум


пока не приходил автовакуум, видно что размер файла значително увеличился:
- данные: 
-    (1000000) * ~45 bytes (с добавлением 5 символов)
-    (4999821) * ~43 bytes (с добавлением в среднем 3 символа)
- HeapTupleHeader: (1000000 + 4999821) * 23 bytes
- Item Identifier: (1000000 + 4999821) * 4 bytes
= 421987470
Что вообше не далеко от того, что мы видим на диске.

```sql
postgres=# SELECT relname, n_live_tup, n_dead_tup,
trunc(100*n_dead_tup/(n_live_tup+1))::float AS "ratio%", last_autovacuum
FROM pg_stat_user_tables WHERE relname = 'test_table';
  relname   | n_live_tup | n_dead_tup | ratio% |       last_autovacuum
------------+------------+------------+--------+------------------------------
 test_table |    1000000 |    4999821 |    499 | 2025-11-11 18:17:44.05992+00
(1 row)
```
```sh
root@ubt-pg-aduron:~# ls -lrt /mnt/data/15/main/base/5/16523*
-rw------- 1 postgres postgres    122880 Nov 11 18:42 /mnt/data/15/main/base/5/16523_fsm
-rw------- 1 postgres postgres     16384 Nov 11 18:42 /mnt/data/15/main/base/5/16523_vm
-rw------- 1 postgres postgres 426164224 Nov 11 18:43 /mnt/data/15/main/base/5/16523
```

### 12. Подождать некоторое время, проверяя, пришел ли автовакуум


Видим что автовакуум почистил все *dead tuples*
```sql
postgres=# SELECT relname, n_live_tup, n_dead_tup,
trunc(100*n_dead_tup/(n_live_tup+1))::float AS "ratio%", last_autovacuum
FROM pg_stat_user_tables WHERE relname = 'test_table';
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000000 |          0 |      0 | 2025-11-11 18:42:42.815004+00
(1 row)
```


### 13. 5 раз обновить все строчки и добавить к каждой строчке любой символ

```sql
postgres=# select $$update test_table set random_text = random_text||substr(md5(random()::text), 1, 1); $$ from generate_series(1,5) \gexec
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
```

### 14. Посмотреть размер файла с таблицей

В этот раз видим что размер файла нен увеличилсь в таком же масштабе, как во время 1-го ряда *update*.
```sh
root@ubt-pg-aduron:~# ls -lrt /mnt/data/15/main/base/5/16523*
-rw------- 1 postgres postgres     16384 Nov 11 18:47 /mnt/data/15/main/base/5/16523_vm
-rw------- 1 postgres postgres    131072 Nov 11 18:47 /mnt/data/15/main/base/5/16523_fsm
-rw------- 1 postgres postgres 459300864 Nov 11 18:47 /mnt/data/15/main/base/5/16523
```
Так как автовакуум пришел, сушествует достаточно свободного места (свободных страниц) после чистки мертвых строк.
Всё же надо выделить место в пополнении, так как новые строки чуть больщие удаленных (с учетом дополнительних символов) 


### 15. Отключить Автовакуум на конкретной таблице

```sql
postgres=# ALTER TABLE test_table SET (autovacuum_enabled = off);
ALTER TABLE
```

### 16. 10 раз обновить все строчки и добавить к каждой строчке любой символ

```sql
postgres=# select $$update test_table set random_text = random_text||substr(md5(random()::text), 1, 1); $$ from generate_series(1,10) \gexec
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
UPDATE 1000000
```

### 17. Посмотреть размер файла с таблицей

```sql
root@ubt-pg-aduron:~# ls -lrt /mnt/data/15/main/base/5/16523*
-rw------- 1 postgres postgres     16384 Nov 11 18:47 /mnt/data/15/main/base/5/16523_vm
-rw------- 1 postgres postgres    245760 Nov 11 18:51 /mnt/data/15/main/base/5/16523_fsm
-rw------- 1 postgres postgres 921583616 Nov 11 18:51 /mnt/data/15/main/base/5/16523
```

### 18. Объясните полученный результат


Замечается, что количества *n_dead_tup* больше не меняется, и что автовакуум больше не запускается на данной таблице. 
Также Видно что размер файла значительно увеличивается, так как автовакуум больше не может освободить мертвых строх:

```sql
postgres=# SELECT relname, n_live_tup, n_dead_tup,
trunc(100*n_dead_tup/(n_live_tup+1))::float AS "ratio%", last_autovacuum
FROM pg_stat_user_tables WHERE relname = 'test_table';
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000000 |    9997238 |    999 | 2025-11-11 18:47:44.166743+00
(1 row)
```

Размер таблице
   - live: (60+27)*1000000 (с добавлением 20 символов с начала теста)
   - dead: (~56+27)*9997238

(60+27) * 1000000 + (56+27) * 9997238 = 916758968 Bytes

Что хорошо совпадает с текущим размером файла: 
```sql
              metric               |   bytes   | bytes_pretty | bytes_per_row
-----------------------------------+-----------+--------------+---------------
 core_relation_size                | 921583616 | 879 MB       |           921
 visibility_map                    |     16384 | 16 kB        |             0
 free_space_map                    |    245760 | 240 kB       |             0
 table_size_incl_toast             | 921853952 | 879 MB       |           921
 indexes_size                      |         0 | 0 bytes      |             0
 total_size_incl_toast_and_indexes | 921853952 | 879 MB       |           921
 live_rows_in_text_representation  |  60888896 | 58 MB        |            60
 ------------------------------    |           |              |
 row_count                         |   1000000 |              |
 live_tuples                       |   1000000 |              |
 dead_tuples                       |   9997096 |              |
(11 rows)
```

### 19. Не забудьте включить автовакуум

```sql
ALTER TABLE test_table SET (autovacuum_enabled = on);
```

После включения автовакуума, снова происходит чистка мертвых строк:
```sql
postgres=# SELECT relname, n_live_tup, n_dead_tup,
trunc(100*n_dead_tup/(n_live_tup+1))::float AS "ratio%", last_autovacuum
FROM pg_stat_user_tables WHERE relname = 'test_table';
  relname   | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
------------+------------+------------+--------+-------------------------------
 test_table |    1000000 |          0 |      0 | 2025-11-11 19:15:34.654469+00
(1 row)
```

При этом, размер файла не уменчается (для этого нужно было сделать VACUUM FULL)



## Список использованных источников:

1. [HeapTupleHeaderData - Подробности](https://github.com/postgres/postgres/blob/ee943004466418595363d567f18c053bae407792/src/include/access/htup_details.h) 
2. [Tuple Structure](https://www.interdb.jp/pg/pgsql05/02.html)
