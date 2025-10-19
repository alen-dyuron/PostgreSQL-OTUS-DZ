# Работа с базами данных, пользователями и правами

## Цель

- создание новой базы данных, схемы и таблицы
- создание роли для чтения данных из созданной схемы созданной базы данных
- создание роли для чтения и записи из созданной схемы созданной базы данных

## План

1. создайте новый кластер PostgresSQL 14
2. зайдите в созданный кластер под пользователем postgres
3. создайте новую базу данных testdb
4. зайдите в созданную базу данных под пользователем postgres
5. создайте новую схему testnm
6. создайте новую таблицу t1 с одной колонкой c1 типа integer
7. вставьте строку со значением c1=1
8. создайте новую роль readonly
9. дайте новой роли право на подключение к базе данных testdb
10. дайте новой роли право на использование схемы testnm
11. дайте новой роли право на select для всех таблиц схемы testnm
12. создайте пользователя testread с паролем test123
13. дайте роль readonly пользователю testread
14. зайдите под пользователем testread в базу данных testdb
15. сделайте select * from t1;
16. получилось? (могло если вы делали сами не по шпаргалке и не упустили один существенный момент про который позже)
17. напишите что именно произошло в тексте домашнего задания
18. у вас есть идеи почему? ведь права то дали?
19. посмотрите на список таблиц
20. подсказка в шпаргалке под пунктом 20
21. а почему так получилось с таблицей (если делали сами и без шпаргалки то может у вас все нормально)
22. вернитесь в базу данных testdb под пользователем postgres
23. удалите таблицу t1
24. создайте ее заново но уже с явным указанием имени схемы testnm
25. вставьте строку со значением c1=1
26. зайдите под пользователем testread в базу данных testdb
27. сделайте select * from testnm.t1;
28. получилось?
29. есть идеи почему? если нет - смотрите шпаргалку
30. как сделать так чтобы такое больше не повторялось? если нет идей - смотрите шпаргалку
31. сделайте select * from testnm.t1;
32. получилось?
33. есть идеи почему? если нет - смотрите шпаргалку
34. сделайте select * from testnm.t1;
35. получилось?
37. теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);
38. а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly?
39. есть идеи как убрать эти права? если нет - смотрите шпаргалку
40. если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку - объясните что сделали и почему выполнив указанные в ней команды
41. теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);
42. расскажите что получилось и почему





## Выполнение


### 1. создайте новый кластер PostgresSQL 14

Установка просходить по такому же формату, с добавлением номера версии: 

```sh
aduron@ubt-pg-aduron:~$ sudo apt install postgresql-14
[sudo] password for aduron:
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  postgresql-client-14
Suggested packages:
  postgresql-doc-14
The following NEW packages will be installed:
  postgresql-14 postgresql-client-14
0 upgraded, 2 newly installed, 0 to remove and 1 not upgraded.
Need to get 16.4 MB of archives.
After this operation, 56.9 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-client-14 amd64 14.19-1.pgdg24.04+1 [1,658 kB]
Get:2 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-14 amd64 14.19-1.pgdg24.04+1 [14.7 MB]
Fetched 16.4 MB in 1s (12.7 MB/s)
Preconfiguring packages ...
Selecting previously unselected package postgresql-client-14.
(Reading database ... 91932 files and directories currently installed.)
Preparing to unpack .../postgresql-client-14_14.19-1.pgdg24.04+1_amd64.deb ...
Unpacking postgresql-client-14 (14.19-1.pgdg24.04+1) ...
Selecting previously unselected package postgresql-14.
Preparing to unpack .../postgresql-14_14.19-1.pgdg24.04+1_amd64.deb ...
Unpacking postgresql-14 (14.19-1.pgdg24.04+1) ...
Setting up postgresql-client-14 (14.19-1.pgdg24.04+1) ...
Setting up postgresql-14 (14.19-1.pgdg24.04+1) ...
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

Как для предыдушего ДЗ, приходится создать кластер в.14 таким образом, и дальше запустить его:
```sh
aduron@ubt-pg-aduron:~$ sudo pg_createcluster 14 main
Creating new PostgreSQL cluster 14/main ...
/usr/lib/postgresql/14/bin/initdb -D /var/lib/postgresql/14/main --auth-local peer --auth-host scram-sha-256 --no-instructions
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.UTF-8".
The default database encoding has accordingly been set to "UTF8".
The default text search configuration will be set to "english".

Data page checksums are disabled.

fixing permissions on existing directory /var/lib/postgresql/14/main ... ok
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
14  main    5434 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log

aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
[sudo] password for aduron:
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 online postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
17  main    5432 online postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log

aduron@ubt-pg-aduron:~$ sudo systemctl start postgresql@14-main
aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 online postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 online postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
17  main    5432 online postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log
```


### 2. зайдите в созданный кластер под пользователем postgres


Во первых позволяем подключении извне кластера, чтобы не пришлось больше подключиться к ОС-аккаунту postgres 
```sh
aduron@ubt-pg-aduron:~$ sudo vi /etc/postgresql/14/main/postgresql.conf

aduron@ubt-pg-aduron:~$ sudo cat /etc/postgresql/14/main/postgresql.conf |grep listen
listen_addresses = 'localhost,192.168.56.10'

aduron@ubt-pg-aduron:~$ sudo systemctl restart postgresql@14-main

aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5434
psql: error: connection to server at "192.168.56.10", port 5434 failed: FATAL:  no pg_hba.conf entry for host "192.168.56.10", user "postgres", database "postgres", SSL encryption
connection to server at "192.168.56.10", port 5434 failed: FATAL:  no pg_hba.conf entry for host "192.168.56.10", user "postgres", database "postgres", no encryption
```

Добавим стоку в /etc/postgresql/14/main/pg_hba.conf
```sh
host    all             postgres        192.168.56.10/24        scram-sha-256
```

Теперь понадобится пароль пользователя postgres в БД 
```sh
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5434
Password for user postgres:
psql: error: connection to server at "192.168.56.10", port 5434 failed: FATAL:  password authentication failed for user "postgres"
connection to server at "192.168.56.10", port 5434 failed: FATAL:  password authentication failed for user "postgres"
```

Подключаемся к postgres (в ОС), затем подключаемся к кластеру (peer). Таким образом получается сменить пароль пользователя postgres в БД.
```sh
postgres@ubt-pg-aduron:~$ psql -p 5434
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 14.19 (Ubuntu 14.19-1.pgdg24.04+1))
Type "help" for help.

postgres=# ALTER USER postgres WITH PASSWORD 'postgres';
ALTER ROLE
postgres=# exit
postgres@ubt-pg-aduron:~$ exit
logout
aduron@ubt-pg-aduron:~$
```

Наконец-то можно подключиться к БД извне кластера с УЗ postgres.
```sh
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5434
Password for user postgres:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 14.19 (Ubuntu 14.19-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.
```


### 3. создайте новую базу данных testdb


Здесь пользуемся коммандой *CREATE DATABASE* и проверим с *\l*
```sql
postgres=# CREATE DATABASE testdb WITH OWNER = postgres;
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
 testdb    | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           |
(4 rows)
```


### 4. зайдите в созданную базу данных под пользователем postgres


Снова подключаемся, но в этот раз с добавлением аргумента *-d <название_БД>*
```sh
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5434 -d testdb
Password for user postgres:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 14.19 (Ubuntu 14.19-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

testdb=#
```


### 5. создайте новую схему testnm


Можно создавать схему с помощью *CREATE SCHEMA* и проверить его существование с *\dn*
```sql
testdb=# \dnS
        List of schemas
        Name        |  Owner
--------------------+----------
 information_schema | postgres
 pg_catalog         | postgres
 pg_toast           | postgres
 public             | postgres
(4 rows)

testdb=# CREATE SCHEMA testnm;
CREATE SCHEMA
testdb=# \dnS
        List of schemas
        Name        |  Owner
--------------------+----------
 information_schema | postgres
 pg_catalog         | postgres
 pg_toast           | postgres
 public             | postgres
 testnm             | postgres
(5 rows)
```


### 6. создайте новую таблицу t1 с одной колонкой c1 типа integer

Дальше сделаем *create table* 
```sh
testdb=# create table t1 (c1 integer);
CREATE TABLE
```


### 7. вставьте строку со значением c1=1

```sql
testdb=# insert into t1 values (1);
INSERT 0 1
```


### 8. создайте новую роль readonly

Здесь речь идет о роли, т.е. без прав на *LOGIN* по умолчанию 
```sql
testdb=# create role readonly;
CREATE ROLE
```


### 9. дайте новой роли право на подключение к базе данных testdb

Позволить подключение к определенной базе можно через *grant connect on database*
```sql
testdb=# grant connect on database testdb to readonly;
GRANT

```


### 10. дайте новой роли право на использование схемы testnm 


```sql
testdb=# grant usage on schema testnm to readonly;
GRANT
```


### 11. дайте новой роли право на select для всех таблиц схемы testnm



```sql
testdb=# GRANT SELECT ON ALL TABLES IN SCHEMA testnm TO readonly;
GRANT
(1 row)
```


### 12. создайте пользователя testread с паролем test123 


Можно это сделть либо с *create user*, либо с *create role with login*
```sql
testdb=# create role testread
testdb-# with
testdb-# login
testdb-# password 'test123';
CREATE ROLE
```


### 13. дайте роль readonly пользователю testread

```sql
testdb=# grant readonly to testread
testdb-# ;
GRANT ROLE
```


### 14. зайдите под пользователем testread в базу данных testdb


Опять таки, нужно настроить pg_hba.conf так, чтобы допускать testread подключаться:
```sh
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U testread -p 5434 -d testdb
psql: error: connection to server at "192.168.56.10", port 5434 failed: FATAL:  no pg_hba.conf entry for host "192.168.56.10", user "testread", database "testdb", SSL encryption
connection to server at "192.168.56.10", port 5434 failed: FATAL:  no pg_hba.conf entry for host "192.168.56.10", user "testread", database "testdb", no encryption
```

```sh
aduron@ubt-pg-aduron:~$ sudo vi /etc/postgresql/14/main/pg_hba.conf
[sudo] password for aduron:
```

Добавляем такую строку
```sh
host    all             testread        192.168.56.10/24        scram-sha-256
```

Перезапускаем кластер и проверяем доступ:
```sh
aduron@ubt-pg-aduron:~$ sudo systemctl restart postgresql@14-main
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U testread -p 5434 -d testdb
Password for user testread:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 14.19 (Ubuntu 14.19-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

testdb=>
```


### 15. сделайте select * from t1; 

```sh
testdb=> select * from t1;
ERROR:  permission denied for table t1
```


### 16. получилось?

Неть!


### 17. напишите что именно произошло в тексте домашнего задания

Подключив под *testread*, Мы находимся по умолчанию в схеме *public*
```sh
testdb=> select current_schema();
 current_schema
----------------
 public
(1 row)
```

Это нормально, т.к. не существует схема пож названием *testread*, и search_path настроен вот таким образом:
```sql
testdb=> SHOW search_path;
   search_path
-----------------
 "$user", public
(1 row)
```

### 18. у вас есть идеи почему? ведь права то дали? 


Да, права дали.
к всем таблицам, которые находятся в схеме testnm
*wait a minute...*
```sql
testdb=# SELECT *
  FROM information_schema.role_table_grants
 WHERE grantee = 'readonly';
 grantor | grantee | table_catalog | table_schema | table_name | privilege_type | is_grantable | with_hierarchy
---------+---------+---------------+--------------+------------+----------------+--------------+----------------
(0 rows)
```


### 19. посмотрите на список таблиц

```sql
testdb=# SELECT * FROM pg_catalog.pg_tables where tablename = 't1';
 schemaname | tablename | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity
------------+-----------+------------+------------+------------+----------+-------------+-------------
 public     | t1        | postgres   |            | f          | f        | f           | f
(1 row)
```


### 20. подсказка в шпаргалке под пунктом 20

Если предоставим права на чтение таблиц в схеме public:
```sql
testdb=# GRANT SELECT ON ALL TABLES IN SCHEMA public to readonly;
GRANT
```

Конечно получается выполнить запрос:
```sql
testdb=> select * from t1;
 c1
----
  1
(1 row)
```


### 21. а почему так получилось с таблицей (если делали сами и без шпаргалки то может у вас все нормально) 


Так получается потому что мы не указади названия схемы, поэтому схема определяется в зависимости от search_path 
```sh
testdb=> SHOW search_path;
   search_path
-----------------
 "$user", public
(1 row)
```

более того, не существует схема *testread* ($user) как указано с командой *\dnS*
```sql
testdb=# \dnS
        List of schemas
        Name        |  Owner
--------------------+----------
 information_schema | postgres
 pg_catalog         | postgres
 pg_toast           | postgres
 public             | postgres
 testnm             | postgres
(5 rows)
```

так что единственная подходяхая схема при выполнения такого *CREATE TABLE* - public.


### 22. вернитесь в базу данных testdb под пользователем postgres 

```sh
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U postgres -p 5434 -d testdb
Password for user postgres:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 14.19 (Ubuntu 14.19-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

```


### 23. удалите таблицу t1 

```sh
testdb=# drop table public.t1;
DROP TABLE
```


### 24. создайте ее заново но уже с явным указанием имени схемы testnm

```sql
testdb=# create table testnm.t1 (c1 integer);
CREATE TABLE
```


### 25. вставьте строку со значением c1=1

```sh
testdb=# insert into testnm.t1 values (1);
INSERT 0 1
```


### 26. зайдите под пользователем testread в базу данных testdb

```sh
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U testread -p 5434 -d testdb
Password for user testread:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 14.19 (Ubuntu 14.19-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.
```


### 27. сделайте select * from testnm.t1;

```sql
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
```


### 28. получилось?

Неть!


### 29. есть идеи почему?

У нас всё же нет прав на select 
```sql
testdb=# SELECT *
  FROM information_schema.role_table_grants
 WHERE grantee = 'readonly';
 grantor | grantee | table_catalog | table_schema | table_name | privilege_type | is_grantable | with_hierarchy
---------+---------+---------------+--------------+------------+----------------+--------------+----------------
(0 rows)
```

### 30. как сделать так чтобы такое больше не повторялось?

Давай сделаем так, чтобы мы полочили достук ко всем таблицам, которых создадим в *testnm* 
```sql
testdb=# ALTER DEFAULT PRIVILEGES IN SCHEMA testnm GRANT SELECT ON TABLES TO readonly;
ALTER DEFAULT PRIVILEGES
testdb=#  \ddp
            Default access privileges
  Owner   | Schema | Type  |  Access privileges
----------+--------+-------+---------------------
 postgres | testnm | table | readonly=r/postgres
(1 row)
```
Отлично выглядит.

### 31. сделайте select * from testnm.t1;

```sql
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
testdb=> exit
```


### 32. получилось?

Нетути!


### 33. есть идеи почему?

Ага. Это же старая таблица, а не новая. Для нее сделаем обычный *grant*: 
```sql
testdb=# grant select on testnm.t1 to  readonly;
GRANT
testdb=# SELECT *
  FROM information_schema.role_table_grants
 WHERE grantee = 'readonly';
 grantor  | grantee  | table_catalog | table_schema | table_name | privilege_type | is_grantable | with_hierarchy
----------+----------+---------------+--------------+------------+----------------+--------------+----------------
 postgres | readonly | testdb        | testnm       | t1         | SELECT         | NO           | YES
(1 row)
```


### 34. сделайте select * from testnm.t1;

```sql
testdb=> select * from testnm.t1;
 c1
----
  1
(1 row)
```


### 35. получилось?

Ага!
При чём мы теперь можем создавать новые таблицы, и овтоматично получить на них права на селект. 
```sh
testdb=# create table testnm.t1_bis(c1 integer);
CREATE TABLE
testdb=# insert into testnm.t1_bis values (2);
INSERT 0 1
testdb=#  SELECT *
  FROM information_schema.role_table_grants
 WHERE grantee = 'readonly';
 grantor  | grantee  | table_catalog | table_schema | table_name | privilege_type | is_grantable | with_hierarchy
----------+----------+---------------+--------------+------------+----------------+--------------+----------------
 postgres | readonly | testdb        | testnm       | t1         | SELECT         | NO           | YES
 postgres | readonly | testdb        | testnm       | t1_bis     | SELECT         | NO           | YES
(2 rows)
```


### 37. теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);

```sql
testdb=> create table t2(c1 integer);
CREATE TABLE
testdb=> insert into t2 values (2);
INSERT 0 1
```


### 38. а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly?

Всё таки права на CREATE есть:
```sql
testdb=> WITH "names"("name") AS (
  SELECT n.nspname AS "name"
    FROM pg_catalog.pg_namespace n
      WHERE n.nspname !~ '^pg_'
        AND n.nspname <> 'information_schema'
) SELECT "name",
  pg_catalog.has_schema_privilege(current_user, "name", 'CREATE') AS "create",
  pg_catalog.has_schema_privilege(current_user, "name", 'USAGE') AS "usage"
    FROM "names";
  name  | create | usage
--------+--------+-------
 public | t      | t
 testnm | f      | t
(2 rows)
```


> [!NOTE]
> Следующая [страница](https://www.percona.com/blog/public-schema-security-upgrade-in-postgresql-15/) обьясняет причину этого поведения в Постгресе до версии 14.
> 
> *Up to Postgres 14, whenever you create a database user, by default, it gets created with CREATE and USAGE privileges on the public schema*
>
> Такое поведение больше не актуально с версии 15, и теперь права на CREATE автоматично удаляеться при содвание роли. 



### 39. есть идеи как убрать эти права? 

Убрать права c *testread*
```sql
testdb=# revoke create on schema public from testread;
REVOKE

testdb=> WITH "names"("name") AS (
  SELECT n.nspname AS "name"
    FROM pg_catalog.pg_namespace n
      WHERE n.nspname !~ '^pg_'
        AND n.nspname <> 'information_schema'
) SELECT "name",
  pg_catalog.has_schema_privilege(current_user, "name", 'CREATE') AS "create",
  pg_catalog.has_schema_privilege(current_user, "name", 'USAGE') AS "usage"
    FROM "names";
  name  | create | usage
--------+--------+-------
 public | t      | t
 testnm | f      | t
(2 rows)
```

Нет!
Убрать права из *readonly*, так как подозрываем что получили этот грант через него?
```sql
testdb=# revoke create on schema public from readonly;
REVOKE

testdb=> WITH "names"("name") AS (
  SELECT n.nspname AS "name"
    FROM pg_catalog.pg_namespace n
      WHERE n.nspname !~ '^pg_'
        AND n.nspname <> 'information_schema'
) SELECT "name",
  pg_catalog.has_schema_privilege(current_user, "name", 'CREATE') AS "create",
  pg_catalog.has_schema_privilege(current_user, "name", 'USAGE') AS "usage"
    FROM "names";
  name  | create | usage
--------+--------+-------
 public | t      | t
 testnm | f      | t
(2 rows)
```

Тоже нет!


### 40. если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку - объясните что сделали и почему выполнив указанные в ней команды

Ответ можно найти [тут](https://dba.stackexchange.com/questions/261542/postgres-revoke-access-to-public-schema-for-a-user)
```sql
testdb=# revoke create on schema public from public;
REVOKE
testdb=# exit
aduron@ubt-pg-aduron:~$ psql -h 192.168.56.10 -U testread -p 5434 -d testdb
Password for user testread:
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 14.19 (Ubuntu 14.19-1.pgdg24.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: none)
Type "help" for help.

testdb=>  WITH "names"("name") AS (
  SELECT n.nspname AS "name"
    FROM pg_catalog.pg_namespace n
      WHERE n.nspname !~ '^pg_'
        AND n.nspname <> 'information_schema'
) SELECT "name",
  pg_catalog.has_schema_privilege(current_user, "name", 'CREATE') AS "create",
  pg_catalog.has_schema_privilege(current_user, "name", 'USAGE') AS "usage"
    FROM "names";
  name  | create | usage
--------+--------+-------
 testnm | f      | t
 public | f      | t
(2 rows)
```
Наконец-то этих прав больше нет


### 41. теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);

```sql
testdb=> create table t3(c1 integer);
ERROR:  permission denied for schema public
LINE 1: create table t3(c1 integer);
                     ^
```

Больше не можем этого делать, так как в *search_path* не осталось ни одной схемы с правами на CREATE, которую мы смогли использовать при выполнении такого запроса.


### 42. расскажите что получилось и почему

Не могу, так как [это болшая тема](
https://ru.wikipedia.org/wiki/%D0%9E%D1%82%D0%B2%D0%B5%D1%82_%D0%BD%D0%B0_%D0%B3%D0%BB%D0%B0%D0%B2%D0%BD%D1%8B%D0%B9_%D0%B2%D0%BE%D0%BF%D1%80%D0%BE%D1%81_%D0%B6%D0%B8%D0%B7%D0%BD%D0%B8,_%D0%B2%D1%81%D0%B5%D0%BB%D0%B5%D0%BD%D0%BD%D0%BE%D0%B9_%D0%B8_%D0%B2%D1%81%D0%B5%D0%B3%D0%BE_%D1%82%D0%B0%D0%BA%D0%BE%D0%B3%D0%BE)


## Список использованных источников:

1. [Public Schema Security Upgrade in PostgreSQL 15](https://www.percona.com/blog/public-schema-security-upgrade-in-postgresql-15/)
2. [Postgres - Revoke access to public schema for a user](https://dba.stackexchange.com/questions/261542/postgres-revoke-access-to-public-schema-for-a-user)