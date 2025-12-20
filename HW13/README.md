# Бэкапы

## Цель

- применить логический бэкап;
- восстановиться из бэкапа;

## План

1. Развернуть PostgreSQL (ВМ/Docker).
2. В БД test_db создать схему my_schema и две одинаковые таблицы (table1, table2).
3. Заполнить table1 100 строками с помощью generate_series.
4. Создать каталог /var/lib/postgresql/backups/ под пользователем postgres.
5. Бэкап через COPY: Выгрузить table1 в CSV командой \copy.
6. Восстановление из COPY: Загрузить данные из CSV в table2.
7. Бэкап через pg_dump: Создать кастомный сжатый дамп (-Fc) только схемы my_schema:
8. Восстановление через pg_restore: В новую БД restored_db восстановить только table2 из дампа:

Важно: Предварительно создать схему my_schema в restored_db.

## Выполнение

### 1. Развернуть PostgreSQL (ВМ/Docker).


Создадим новый кластер в 16
```sh
aduron@ubt-pg-aduron:~$ sudo apt install postgresql-16
[sudo] password for aduron:
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following NEW packages will be installed:
  postgresql-16
0 upgraded, 1 newly installed, 0 to remove and 11 not upgraded.
Need to get 16.3 MB of archives.
After this operation, 57.5 MB of additional disk space will be used.
Get:1 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-16 amd64 16.11-1.pgdg24.04+1 [16.3 MB]
Fetched 16.3 MB in 2s (9,006 kB/s)
Preconfiguring packages ...
Selecting previously unselected package postgresql-16.
(Reading database ... 165786 files and directories currently installed.)
Preparing to unpack .../postgresql-16_16.11-1.pgdg24.04+1_amd64.deb ...
Unpacking postgresql-16 (16.11-1.pgdg24.04+1) ...
Setting up postgresql-16 (16.11-1.pgdg24.04+1) ...
Processing triggers for postgresql-common (285.pgdg24.04+1) ...
Building PostgreSQL dictionaries from installed myspell/hunspell packages...
Removing obsolete dictionary files:
Scanning processes...
Scanning linux images...

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

```sh
aduron@ubt-pg-aduron:~$ sudo pg_createcluster 16 main
Creating new PostgreSQL cluster 16/main ...
/usr/lib/postgresql/16/bin/initdb -D /var/lib/postgresql/16/main --auth-local peer --auth-host scram-sha-256 --no-instructions
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.UTF-8".
The default database encoding has accordingly been set to "UTF8".
The default text search configuration will be set to "english".

Data page checksums are disabled.

fixing permissions on existing directory /var/lib/postgresql/16/main ... ok
creating subdirectories ... ok
selecting dynamic shared memory implementation ... posix
selecting default max_connections ... 100
selecting default shared_buffers ... 128MB
selecting default time zone ... Etc/UTC
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok
syncing data to disk ... ok
Ver Cluster Port Status Owner    Data directory              Log file
16  main    5435 down   postgres /var/lib/postgresql/16/main /var/log/postgresql/postgresql-16-main.log
```

Запустим его и стопнить всё остальное
```sh
aduron@ubt-pg-aduron:~$ sudo systemctl start postgresql@16-main
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@14-main
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@15-main
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@17-main
aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 down   postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
16  main    5435 online postgres /var/lib/postgresql/16/main /var/log/postgresql/postgresql-16-main.log
17  main    5432 down   postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log
```


### 2. В БД test_db создать схему my_schema и две одинаковые таблицы (table1, table2).

Создадим новую базу *test_db*
```sql
aduron@ubt-pg-aduron:~$ sudo su - postgres
postgres@ubt-pg-aduron:~$ psql -p 5435
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 16.11 (Ubuntu 16.11-1.pgdg24.04+1))
Type "help" for help.

postgres=# ALTER USER postgres WITH PASSWORD 'postgres';
ALTER ROLE
postgres=# CREATE DATABASE test_db WITH OWNER = postgres;
CREATE DATABASE
postgres=# \l
                                                     List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
-----------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 test_db   | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
(4 rows)
```

Добавляем стоку в /etc/postgresql/16/main/pg_hba.conf
```sh
host    all             postgres        192.168.56.10/24        scram-sha-256
```

Откомментируем *listen_addresses* и добавляем айпи нашего сервера
```sh
aduron@ubt-pg-aduron:~$ sudo cat /etc/postgresql/16/main/postgresql.conf |grep listen
listen_addresses = 'localhost,192.168.56.10'
aduron@ubt-pg-aduron:~$ sudo systemctl restart postgresql@16-main
```

Проверяем что можно подключаться
```sql
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5435 -d test_db
Password for user postgres:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 16.11 (Ubuntu 16.11-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

test_db=#
```

Создадим схему с помощью *CREATE SCHEMA* и проверяем его существование с *\dn*
```sql
test_db=# CREATE SCHEMA my_schema;
CREATE SCHEMA
test_db=# \dnS
            List of schemas
        Name        |       Owner
--------------------+-------------------
 information_schema | postgres
 my_schema          | postgres
 pg_catalog         | postgres
 pg_toast           | postgres
 public             | pg_database_owner
(5 rows)
```

Создадим новые таблицы расположены в схеме *my_schema*
```sql
test_db=# create table my_schema.table1 (id integer, value text);
CREATE TABLE
test_db=# create table my_schema.table2 (id integer, value text);
CREATE TABLE

test_db=# \d my_schema.table1
             Table "my_schema.table1"
 Column |  Type   | Collation | Nullable | Default
--------+---------+-----------+----------+---------
 id     | integer |           |          |
 value  | text    |           |          |

test_db=# \d my_schema.table2
             Table "my_schema.table2"
 Column |  Type   | Collation | Nullable | Default
--------+---------+-----------+----------+---------
 id     | integer |           |          |
 value  | text    |           |          |
```


### 3. Заполнить table1 100 строками с помощью generate_series.

Добавим данные
```sql
test_db=# insert into my_schema.table1
select
        generate_series(1,100) AS id,
        md5(random()::text) AS value
;
INSERT 0 100
test_db=# select count(*) from my_schema.table1;
 count
-------
   100
(1 row)

test_db=# select * from my_schema.table1 limit 2;
 id |              value
----+----------------------------------
  1 | 9cf0ea6987db44818653c745e9c6dd39
  2 | 646eb20d55574a71f626d81622a7423d
(2 rows)
```


### 4. Создать каталог /var/lib/postgresql/backups/ под пользователем postgres.

```sh
postgres@ubt-pg-aduron:~$ mkdir /var/lib/postgresql/backups
postgres@ubt-pg-aduron:~$ ls -lrt /var/lib/postgresql/
total 28
drwxr-xr-x 3 postgres postgres 4096 Oct 10 18:49 17
drwxr-xr-x 3 root     root     4096 Oct 15 19:26 18
drwxr-xr-x 2 root     root     4096 Oct 19 07:31 15
drwxr-xr-x 3 postgres postgres 4096 Oct 19 12:11 14
drwxrwxr-x 2 postgres postgres 4096 Nov 23 20:55 demo
drwxr-xr-x 3 postgres postgres 4096 Dec 20 19:27 16
drwxrwxr-x 2 postgres postgres 4096 Dec 20 20:11 backups
```


### 5. Бэкап через COPY: Выгрузить table1 в CSV командой \copy.



Сделаем логический бэкап с помощью команды *\copy*
```sql
postgres@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5435 -d test_db
Password for user postgres:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 16.11 (Ubuntu 16.11-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

test_db=# \copy my_schema.table1 to '/var/lib/postgresql/backups/table1.sql';
COPY 100
```

> [!NOTE]
> тут надо иметь права на редактирование в каталоге *backups*, поэтому выполняем эту команду под *postgres*


### 6. Восстановление из COPY: Загрузить данные из CSV в table2.

Загружаем данные из предыдущего бэкапа в *my_schema.table2*
```sql
test_db=# \copy my_schema.table2 from '/var/lib/postgresql/backups/table1.sql';
COPY 100

test_db=# select count(*) from my_schema.table2;
 count
-------
   100
(1 row)
```

Сравниваем и проверяем что именно те данные востановили
```sql
test_db=# select * from my_schema.table2 minus select * from my_schema.table1;
ERROR:  syntax error at or near "select"
LINE 1: select * from my_schema.table2 minus select * from my_schema...
                                             ^
test_db=# select * from my_schema.table2
test_db-# minus
test_db-# select * from my_schema.table1;
ERROR:  syntax error at or near "select"
LINE 3: select * from my_schema.table1;
        ^
```
Оракл моя любовь ((

```sql
test_db=# select * from my_schema.table2
test_db-# except
test_db-# select * from my_schema.table1;
 id | value
----+-------
(0 rows)
```
Всё)



### 7. Бэкап через pg_dump: Создать кастомный сжатый дамп (-Fc) только схемы my_schema:

> [!NOTE]
> тут добавил *-v*, так как без этого команда завершается без подтверждения успешного выполнения.

Сделаем бэкап с командой pg_dump
```sh
postgres@ubt-pg-aduron:~$ pg_dump -v -Fc -p 5435 -d test_db -U postgres -n my_schema > /var/lib/postgresql/backups/test_db.my_schema.dump
pg_dump: last built-in OID is 16383
pg_dump: reading extensions
pg_dump: identifying extension members
pg_dump: reading schemas
pg_dump: reading user-defined tables
pg_dump: reading user-defined functions
pg_dump: reading user-defined types
pg_dump: reading procedural languages
pg_dump: reading user-defined aggregate functions
pg_dump: reading user-defined operators
pg_dump: reading user-defined access methods
pg_dump: reading user-defined operator classes
pg_dump: reading user-defined operator families
pg_dump: reading user-defined text search parsers
pg_dump: reading user-defined text search templates
pg_dump: reading user-defined text search dictionaries
pg_dump: reading user-defined text search configurations
pg_dump: reading user-defined foreign-data wrappers
pg_dump: reading user-defined foreign servers
pg_dump: reading default privileges
pg_dump: reading user-defined collations
pg_dump: reading user-defined conversions
pg_dump: reading type casts
pg_dump: reading transforms
pg_dump: reading table inheritance information
pg_dump: reading event triggers
pg_dump: finding extension tables
pg_dump: finding inheritance relationships
pg_dump: reading column info for interesting tables
pg_dump: flagging inherited columns in subtables
pg_dump: reading partitioning data
pg_dump: reading indexes
pg_dump: flagging indexes in partitioned tables
pg_dump: reading extended statistics
pg_dump: reading constraints
pg_dump: reading triggers
pg_dump: reading rewrite rules
pg_dump: reading policies
pg_dump: reading row-level security policies
pg_dump: reading publications
pg_dump: reading publication membership of tables
pg_dump: reading publication membership of schemas
pg_dump: reading subscriptions
pg_dump: reading dependency data
pg_dump: saving encoding = UTF8
pg_dump: saving standard_conforming_strings = on
pg_dump: saving search_path =
pg_dump: saving database definition
pg_dump: dumping contents of table "my_schema.table1"
pg_dump: dumping contents of table "my_schema.table2"
```

### 8. Восстановление через pg_restore: В новую БД restored_db восстановить только table2 из дампа:

Создадим новую базу для востановления
```sql
postgres=# CREATE DATABASE restore_db WITH OWNER = postgres;
CREATE DATABASE

postgres=# \l
                                                      List of databases
    Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges
------------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 postgres   | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 restore_db | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
 template0  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
            |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
            |          |          |                 |             |             |        |           | postgres=CTc/postgres
 test_db    | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
(5 rows)
```

Проверим как именно восстановить одну определенную таблицу 
```sh
postgres@ubt-pg-aduron:~$ pg_restore --help | grep table
  -L, --use-list=FILENAME      use table of contents from this file for
  -t, --table=NAME             restore named relation (table, view, etc.)
  --no-data-for-failed-tables  do not restore data of tables that could not be
  --no-table-access-method     do not restore table access methods
  --no-tablespaces             do not restore tablespace assignments
  --strict-names               require table and/or schema include patterns to
```

Создадим схему перед востановлением:
```sql
restore_db=# CREATE SCHEMA my_schema;
CREATE SCHEMA
```

Запускаем с такими же флагами как pg_dump, изменив только название базе на *restore_db*, и с добавлением флага *-t* для определения востановленных таблиц. 
```sh
postgres@ubt-pg-aduron:~$ pg_restore -v -Fc -p 5435 -d restore_db -U postgres -n my_schema -t table2 /var/lib/postgresql/backups/test_db.my_schema.dump
pg_restore: connecting to database for restore
pg_restore: creating TABLE "my_schema.table2"
pg_restore: processing data for table "my_schema.table2"
```

Подключаемся и проверим что только наша *table2* была восстановлена
```sh
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5435 -d restore_db
Password for user postgres:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 16.11 (Ubuntu 16.11-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

restore_db=# select count(*) from my_schema.table1;
ERROR:  relation "my_schema.table1" does not exist
LINE 1: select count(*) from my_schema.table1;
                             ^
restore_db=# select count(*) from my_schema.table2;
 count
-------
   100
(1 row)
```


## Ресурсы 

1. [pg_dump documentation](https://www.postgresql.org/docs/current/app-pgdump.html)
