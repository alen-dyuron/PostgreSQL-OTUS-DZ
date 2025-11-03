# Нагрузочное тестирование и тюнинг PostgreSQL

## Цель

- сделать нагрузочное тестирование PostgreSQL
- настроить параметры PostgreSQL для достижения максимальной производительности

## План

1. развернуть виртуальную машину любым удобным способом
2. поставить на неё PostgreSQL 15 любым способом
3. настроить кластер PostgreSQL 15 на максимальную производительность не обращая внимание на возможные проблемы с надежностью в случае аварийной перезагрузки виртуальной машины
4. нагрузить кластер через утилиту через утилиту pgbench (https://postgrespro.ru/docs/postgrespro/14/pgbench)
5. написать какого значения tps удалось достичь, показать какие параметры в какие значения устанавливали и почему

> [!NOTE]
> Задание со \*: аналогично протестировать через утилиту https://github.com/Percona-Lab/sysbench-tpcc (требует установки https://github.com/akopytov/sysbench). 
> Чтобы не полностью выполнить ДЗ повторно, будем это сделать одновременно с нагрузочное тестирование 



## Выполнение


### 1. развернуть виртуальную машину любым удобным способом

Снова используем машину, созданную в рамках предыдущего ДЗ.
В этот раз с добавлением 2 допольнителных проссессоров

```sh
aduron@ubt-pg-aduron:~$ cat /proc/cpuinfo  | grep process| wc -l
4
root@ubt-pg-aduron:~# free
               total        used        free      shared  buff/cache   available
Mem:         8132680      527892     7364420       40424      518628     7604788
Swap:              0           0           0
```

### 2. поставить на неё PostgreSQL 15 любым способом

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
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@17-main
aduron@ubt-pg-aduron:~$ sudo systemctl stop postgresql@14-main
aduron@ubt-pg-aduron:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5434 down   postgres /var/lib/postgresql/14/main /var/log/postgresql/postgresql-14-main.log
15  main    5433 online postgres /mnt/data/15/main           /var/log/postgresql/postgresql-15-main.log
17  main    5432 down   postgres /var/lib/postgresql/17/main /var/log/postgresql/postgresql-17-main.log
```

Pgbench конечно уже есть (вместе с установкой постгресса) 
```sh
aduron@ubt-pg-aduron:~$ pgbench --version
pgbench (PostgreSQL) 17.6 (Ubuntu 17.6-2.pgdg24.04+1)
```

sysbench можно установить таким способом:
```sh
aduron@ubt-pg-aduron:~$ sudo curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
[sudo] password for aduron:
aduron@ubt-pg-aduron:~$ sudo apt -y install sysbench
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libluajit2-5.1-2 libluajit2-5.1-common libmysqlclient21 mysql-common
The following NEW packages will be installed:
  libluajit2-5.1-2 libluajit2-5.1-common libmysqlclient21 mysql-common sysbench
0 upgraded, 5 newly installed, 0 to remove and 3 not upgraded.
Need to get 1,700 kB of archives.
After this operation, 8,084 kB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu noble/universe amd64 libluajit2-5.1-common all 2.1-20230410-1build1 [48.6 kB]
Get:2 http://archive.ubuntu.com/ubuntu noble/universe amd64 libluajit2-5.1-2 amd64 2.1-20230410-1build1 [277 kB]
Get:3 http://archive.ubuntu.com/ubuntu noble/main amd64 mysql-common all 5.8+1.1.0build1 [6,746 B]
Get:4 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 libmysqlclient21 amd64 8.0.43-0ubuntu0.24.04.2 [1,254 kB]
Get:5 http://archive.ubuntu.com/ubuntu noble/universe amd64 sysbench amd64 1.0.20+ds-6build2 [114 kB]
Fetched 1,700 kB in 1s (2,410 kB/s)
Selecting previously unselected package libluajit2-5.1-common.
(Reading database ... 135063 files and directories currently installed.)
Preparing to unpack .../libluajit2-5.1-common_2.1-20230410-1build1_all.deb ...
Unpacking libluajit2-5.1-common (2.1-20230410-1build1) ...
Selecting previously unselected package libluajit2-5.1-2:amd64.
Preparing to unpack .../libluajit2-5.1-2_2.1-20230410-1build1_amd64.deb ...
Unpacking libluajit2-5.1-2:amd64 (2.1-20230410-1build1) ...
Selecting previously unselected package mysql-common.
Preparing to unpack .../mysql-common_5.8+1.1.0build1_all.deb ...
Unpacking mysql-common (5.8+1.1.0build1) ...
Selecting previously unselected package libmysqlclient21:amd64.
Preparing to unpack .../libmysqlclient21_8.0.43-0ubuntu0.24.04.2_amd64.deb ...
Unpacking libmysqlclient21:amd64 (8.0.43-0ubuntu0.24.04.2) ...
Selecting previously unselected package sysbench.
Preparing to unpack .../sysbench_1.0.20+ds-6build2_amd64.deb ...
Unpacking sysbench (1.0.20+ds-6build2) ...
Setting up mysql-common (5.8+1.1.0build1) ...
update-alternatives: using /etc/mysql/my.cnf.fallback to provide /etc/mysql/my.cnf (my.cnf) in auto mode
Setting up libmysqlclient21:amd64 (8.0.43-0ubuntu0.24.04.2) ...
Setting up libluajit2-5.1-common (2.1-20230410-1build1) ...
Setting up libluajit2-5.1-2:amd64 (2.1-20230410-1build1) ...
Setting up sysbench (1.0.20+ds-6build2) ...
Processing triggers for man-db (2.12.0-4build2) ...
Processing triggers for libc-bin (2.39-0ubuntu8.6) ...
Scanning processes...
Scanning linux images...

Pending kernel upgrade!
Running kernel version:
  6.8.0-85-generic
Diagnostics:
  The currently running kernel version is not the expected kernel version 6.8.0-86-generic.

Restarting the system to load the new kernel will not be handled automatically, so you should consider rebooting.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```


> [!NOTE]
> В рамках этого ДЗ к сожалению не успел ползоваться sysbench.



### 3. настроить кластер PostgreSQL 15 на максимальную производительность не обращая внимание на возможные проблемы с надежностью в случае аварийной перезагрузки виртуальной машины


#### 3.1 TPC-B 

[tpc.org](https://tpc.org/tpcb/) объясняет, что TPC-B не рассмотревается как измерение происводительности OLTP, а более как тест нагрузки для СУБД.

_TPC-B can be looked at as a database stress test, characterized by:_
- _Significant disk input/output_
- _Moderate system and application execution time_
- _Transaction integrity_
_TPC-B measures throughput in terms of how many transactions per second a system can perform. Because there are substantial differences between the two benchmarks (OLTP vs. database stress test), TPC-B results cannot be compared to TPC-A._

Соответственно, ожидаем что большая часть улучшения произподительнось будет связана с измениениями настроек как *fsync* и *synchronous_commit*, которые влияют на целостность транзакции и производителность дисков.   

[Подробности](https://jimgray.azurewebsites.net/benchmarkhandbook/tpcb.pdf) тестирования TPC-B:

```sql
BEGIN TRANSACTION
 Update Account where Account_ID = Aid:
    Read Account_Balance from Account
    Set Account_Balance = Account_Balance + Delta
    Write Account_Balance to Account
  Write to History:
    Aid, Tid, Bid, Delta, Time_stamp
  Update Teller where Teller_ID = Tid:
    Set Teller_Balance = Teller_Balance + Delta
    Write Teller_Balance to Teller
  Update Branch where Branch_ID = Bid:
    Set Branch_Balance = Branch_Balance + Delta
    Write Branch_Balance to Branch
COMMIT TRANSACTION
Return Account_Balance to driver
```

#### 3.2 Подготовка к тестированию

Для того чтобы подготовить утилиту к тестированию, нужно сначала его запустить с опцией -i следуючим образом

```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -i
Password:
dropping old tables...
NOTICE:  table "pgbench_accounts" does not exist, skipping
NOTICE:  table "pgbench_branches" does not exist, skipping
NOTICE:  table "pgbench_history" does not exist, skipping
NOTICE:  table "pgbench_tellers" does not exist, skipping
creating tables...
generating data (client-side)...
vacuuming...
creating primary keys...
done in 0.33 s (drop tables 0.01 s, create tables 0.02 s, client-side generate 0.13 s, vacuum 0.07 s, primary keys 0.11 s).
```

#### 3.3 бэйзлайн 

Во первых собираем базовую производительность, то есть запускаем утилиту pgbench без каких-либо изменений в настройках:
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 1065.6 tps, lat 41.490 ms stddev 52.778, 0 failed
progress: 10.0 s, 1324.0 tps, lat 37.938 ms stddev 49.978, 0 failed
progress: 15.0 s, 1335.6 tps, lat 37.298 ms stddev 43.168, 0 failed
progress: 20.0 s, 1276.2 tps, lat 38.742 ms stddev 51.912, 0 failed
progress: 25.0 s, 1251.8 tps, lat 40.515 ms stddev 51.276, 0 failed
progress: 30.0 s, 1256.4 tps, lat 39.754 ms stddev 46.846, 0 failed
progress: 35.0 s, 1181.0 tps, lat 42.346 ms stddev 56.127, 0 failed
progress: 40.0 s, 1179.6 tps, lat 41.867 ms stddev 54.763, 0 failed
progress: 45.0 s, 1235.6 tps, lat 40.924 ms stddev 54.039, 0 failed
progress: 50.0 s, 1345.4 tps, lat 37.202 ms stddev 46.756, 0 failed
progress: 55.0 s, 1339.9 tps, lat 37.315 ms stddev 45.339, 0 failed
progress: 60.0 s, 1269.3 tps, lat 39.094 ms stddev 51.010, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 75352
number of failed transactions: 0 (0.000%)
latency average = 39.506 ms
latency stddev = 50.443 ms
initial connection time = 513.148 ms
tps = 1264.144326 (without initial connection time)
```


### 4. нагрузить кластер через утилиту через утилиту pgbench (https://postgrespro.ru/docs/postgrespro/14/pgbench)

Мы проверим влияние и действие следующих настроек, о котором мы разговоривали на занятии.

|               name               | setting | unit |
|----------------------------------|---------|------|
| checkpoint_completion_target     | 0.9     |      |
| effective_cache_size             | 524288  | 8kB  |
| effective_io_concurrency         | 1       |      |
| fsync                            | on      |      |
| geqo                             | on      |      |
| join_collapse_limit              | 8       |      |
| maintenance_work_mem             | 65536   | kB   |
| max_parallel_maintenance_workers | 2       |      |
| max_parallel_workers             | 8       |      |
| max_parallel_workers_per_gather  | 2       |      |
| max_worker_processes             | 8       |      |
| random_page_cost                 | 4       |      |
| shared_buffers                   | 16384   | 8kB  |
| synchronous_commit               | on      |      |
| temp_buffers                     | 1024    | 8kB  |
| work_mem                         | 4096    | kB   |
| wal_buffers                      | 512     | 8kB  |


> [!IMPORTANT]
> Это ДЗ был выполнен 2 раза, так как в первый раз сразу менял настройки _synchronous\_commit_ и _fsync_, что не позволило проверить эффективность и действие всех других настроек.



#### 4.1. max_worker_processes

```sh
postgres=# alter system set max_worker_processes=16;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ sudo systemctl restart postgresql@15-main
[sudo] password for aduron:
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 907.2 tps, lat 49.448 ms stddev 61.138, 0 failed
progress: 10.0 s, 1078.4 tps, lat 46.601 ms stddev 59.145, 0 failed
progress: 15.0 s, 1296.6 tps, lat 38.573 ms stddev 45.333, 0 failed
progress: 20.0 s, 1209.6 tps, lat 41.160 ms stddev 57.836, 0 failed
progress: 25.0 s, 1325.6 tps, lat 37.754 ms stddev 41.989, 0 failed
progress: 30.0 s, 1262.2 tps, lat 39.734 ms stddev 50.839, 0 failed
progress: 35.0 s, 1274.8 tps, lat 39.094 ms stddev 46.381, 0 failed
progress: 40.0 s, 1307.4 tps, lat 38.324 ms stddev 49.936, 0 failed
progress: 45.0 s, 1268.2 tps, lat 39.290 ms stddev 45.851, 0 failed
progress: 50.0 s, 1177.4 tps, lat 42.418 ms stddev 57.745, 0 failed
progress: 55.0 s, 1278.4 tps, lat 39.133 ms stddev 48.724, 0 failed
progress: 60.0 s, 1270.1 tps, lat 39.495 ms stddev 49.687, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 73330
number of failed transactions: 0 (0.000%)
latency average = 40.635 ms
latency stddev = 51.199 ms
initial connection time = 440.622 ms
tps = 1229.334733 (without initial connection time)

```

#### 4.2. max_parallel_workers

```sh
postgres=# alter system set max_parallel_workers=16;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 928.1 tps, lat 48.615 ms stddev 56.110, 0 failed
progress: 10.0 s, 1021.2 tps, lat 48.907 ms stddev 61.167, 0 failed
progress: 15.0 s, 1156.0 tps, lat 43.469 ms stddev 55.381, 0 failed
progress: 20.0 s, 1373.6 tps, lat 36.099 ms stddev 47.457, 0 failed
progress: 25.0 s, 1208.2 tps, lat 41.582 ms stddev 51.918, 0 failed
progress: 30.0 s, 1228.4 tps, lat 40.693 ms stddev 52.682, 0 failed
progress: 35.0 s, 1169.2 tps, lat 42.511 ms stddev 50.733, 0 failed
progress: 40.0 s, 1226.0 tps, lat 41.043 ms stddev 53.570, 0 failed
progress: 45.0 s, 1254.0 tps, lat 39.830 ms stddev 51.971, 0 failed
progress: 50.0 s, 1198.4 tps, lat 41.713 ms stddev 60.314, 0 failed
progress: 55.0 s, 1181.8 tps, lat 42.303 ms stddev 58.606, 0 failed
progress: 60.0 s, 1300.6 tps, lat 38.445 ms stddev 49.702, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 71280
number of failed transactions: 0 (0.000%)
latency average = 41.808 ms
latency stddev = 54.161 ms
initial connection time = 430.162 ms
tps = 1194.748157 (without initial connection time)
```
Так как именение не принесло никакой пользы, восстановил дефольтное значение таким способом:
```sh
postgres=# alter system reset max_parallel_workers;
ALTER SYSTEM
```

#### 4.3. max_parallel_maintenance_workers

```sh
postgres=# alter system set max_parallel_maintenance_workers=4;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 918.0 tps, lat 49.035 ms stddev 63.775, 0 failed
progress: 10.0 s, 1023.4 tps, lat 48.906 ms stddev 61.767, 0 failed
progress: 15.0 s, 1115.6 tps, lat 44.798 ms stddev 61.452, 0 failed
progress: 20.0 s, 1375.2 tps, lat 36.414 ms stddev 51.347, 0 failed
progress: 25.0 s, 1422.4 tps, lat 35.276 ms stddev 43.263, 0 failed
progress: 30.0 s, 1308.8 tps, lat 38.059 ms stddev 44.634, 0 failed
progress: 35.0 s, 1198.0 tps, lat 41.790 ms stddev 50.799, 0 failed
progress: 40.0 s, 1275.4 tps, lat 39.244 ms stddev 53.714, 0 failed
progress: 45.0 s, 1321.6 tps, lat 37.794 ms stddev 48.894, 0 failed
progress: 50.0 s, 1247.4 tps, lat 40.069 ms stddev 49.057, 0 failed
progress: 55.0 s, 1187.2 tps, lat 42.014 ms stddev 51.673, 0 failed
progress: 60.0 s, 1336.0 tps, lat 37.299 ms stddev 48.880, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 73695
number of failed transactions: 0 (0.000%)
latency average = 40.441 ms
latency stddev = 52.397 ms
initial connection time = 430.897 ms
tps = 1235.118515 (without initial connection time)
```
Так как именение не принесло никакой пользы, восстановил дефольтное значение таким способом:
```sh
postgres=# alter system reset max_parallel_maintenance_workers;
ALTER SYSTEM
```


#### 4.4. effective_io_concurrency

```sh
postgres=# alter system set effective_io_concurrency=2;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 909.6 tps, lat 49.118 ms stddev 54.914, 0 failed
progress: 10.0 s, 981.8 tps, lat 51.174 ms stddev 63.821, 0 failed
progress: 15.0 s, 1259.2 tps, lat 39.678 ms stddev 47.055, 0 failed
progress: 20.0 s, 1369.0 tps, lat 36.535 ms stddev 51.440, 0 failed
progress: 25.0 s, 1361.9 tps, lat 36.505 ms stddev 42.532, 0 failed
progress: 30.0 s, 1193.7 tps, lat 41.977 ms stddev 50.189, 0 failed
progress: 35.0 s, 1191.8 tps, lat 41.960 ms stddev 51.989, 0 failed
progress: 40.0 s, 1201.6 tps, lat 41.443 ms stddev 49.913, 0 failed
progress: 45.0 s, 1209.6 tps, lat 41.434 ms stddev 47.331, 0 failed
progress: 50.0 s, 1179.2 tps, lat 42.417 ms stddev 59.834, 0 failed
progress: 55.0 s, 1315.2 tps, lat 37.976 ms stddev 44.457, 0 failed
progress: 60.0 s, 1343.0 tps, lat 37.309 ms stddev 45.822, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 72628
number of failed transactions: 0 (0.000%)
latency average = 41.005 ms
latency stddev = 50.824 ms
initial connection time = 468.925 ms
tps = 1218.233882 (without initial connection time)
```
Так как именение не принесло никакой пользы, восстановил дефольтное значение таким способом:
```sh
postgres=# alter system reset effective_io_concurrency;
ALTER SYSTEM
```


#### 4.5. work_mem


```sh
postgres=# alter system set work_mem=8192;;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 1010.0 tps, lat 44.614 ms stddev 56.754, 0 failed
progress: 10.0 s, 1347.0 tps, lat 37.150 ms stddev 44.033, 0 failed
progress: 15.0 s, 1335.2 tps, lat 37.221 ms stddev 49.210, 0 failed
progress: 20.0 s, 1288.6 tps, lat 38.869 ms stddev 52.815, 0 failed
progress: 25.0 s, 1181.4 tps, lat 42.450 ms stddev 54.854, 0 failed
progress: 30.0 s, 1317.4 tps, lat 37.879 ms stddev 52.548, 0 failed
progress: 35.0 s, 1350.6 tps, lat 37.081 ms stddev 46.778, 0 failed
progress: 40.0 s, 1326.6 tps, lat 37.657 ms stddev 47.973, 0 failed
progress: 45.0 s, 1123.8 tps, lat 44.163 ms stddev 62.266, 0 failed
progress: 50.0 s, 1355.8 tps, lat 37.174 ms stddev 46.235, 0 failed
progress: 55.0 s, 1307.2 tps, lat 38.092 ms stddev 46.166, 0 failed
progress: 60.0 s, 1331.4 tps, lat 37.693 ms stddev 50.745, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 76424
number of failed transactions: 0 (0.000%)
latency average = 38.984 ms
latency stddev = 50.846 ms
initial connection time = 451.640 ms
tps = 1281.417847 (without initial connection time)
```

#### 4.6. effective_cache_size

Для этой настройки часто рекомендуется ставить значение столбца cached от команды free, в нашем случае 1047080.
```sh
aduron@ubt-pg-aduron:~$ free
               total        used        free      shared  buff/cache   available
Mem:         8131876      523292     6855532       43664     1047080     7608584
Swap:              0           0           0
```

```sh
postgres=# alter system set effective_cache_size = 1047080;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 900.0 tps, lat 49.797 ms stddev 63.120, 0 failed
progress: 10.0 s, 1013.2 tps, lat 49.195 ms stddev 62.220, 0 failed
progress: 15.0 s, 1018.2 tps, lat 49.238 ms stddev 58.811, 0 failed
progress: 20.0 s, 1073.2 tps, lat 46.662 ms stddev 59.258, 0 failed
progress: 25.0 s, 1205.6 tps, lat 41.593 ms stddev 54.200, 0 failed
progress: 30.0 s, 1311.4 tps, lat 37.960 ms stddev 50.646, 0 failed
progress: 35.0 s, 1357.8 tps, lat 36.930 ms stddev 47.718, 0 failed
progress: 40.0 s, 1209.2 tps, lat 41.349 ms stddev 61.953, 0 failed
progress: 45.0 s, 1238.4 tps, lat 40.372 ms stddev 49.301, 0 failed
progress: 50.0 s, 1312.8 tps, lat 38.082 ms stddev 48.164, 0 failed
progress: 55.0 s, 1337.4 tps, lat 37.397 ms stddev 47.373, 0 failed
progress: 60.0 s, 1208.8 tps, lat 41.307 ms stddev 54.625, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 70980
number of failed transactions: 0 (0.000%)
latency average = 41.970 ms
latency stddev = 54.692 ms
initial connection time = 453.178 ms
tps = 1190.176886 (without initial connection time)
```


#### 4.7. shared_buffers

```sh
postgres=# alter system set shared_buffers=65536;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 920.4 tps, lat 48.071 ms stddev 56.271, 0 failed
progress: 10.0 s, 1020.2 tps, lat 49.583 ms stddev 63.160, 0 failed
progress: 15.0 s, 950.8 tps, lat 52.549 ms stddev 69.752, 0 failed
progress: 20.0 s, 1356.6 tps, lat 36.933 ms stddev 47.071, 0 failed
progress: 25.0 s, 1286.0 tps, lat 38.833 ms stddev 46.602, 0 failed
progress: 30.0 s, 1354.8 tps, lat 36.796 ms stddev 43.216, 0 failed
progress: 35.0 s, 1273.8 tps, lat 39.258 ms stddev 54.234, 0 failed
progress: 40.0 s, 1322.4 tps, lat 37.863 ms stddev 48.816, 0 failed
progress: 45.0 s, 1314.2 tps, lat 38.100 ms stddev 50.466, 0 failed
progress: 50.0 s, 1231.4 tps, lat 40.228 ms stddev 53.527, 0 failed
progress: 55.0 s, 1094.0 tps, lat 46.009 ms stddev 58.838, 0 failed
progress: 60.0 s, 1198.0 tps, lat 41.783 ms stddev 49.415, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 71662
number of failed transactions: 0 (0.000%)
latency average = 41.558 ms
latency stddev = 53.378 ms
initial connection time = 468.496 ms
tps = 1201.972629 (without initial connection time)

```

#### 4.8. synchronous_commit

```sh
postgres=# alter system set synchronous_commit=off;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 1695.4 tps, lat 25.757 ms stddev 32.999, 0 failed
progress: 10.0 s, 1910.6 tps, lat 26.264 ms stddev 33.973, 0 failed
progress: 15.0 s, 2048.4 tps, lat 24.442 ms stddev 31.712, 0 failed
progress: 20.0 s, 2034.3 tps, lat 24.402 ms stddev 29.696, 0 failed
progress: 25.0 s, 1845.0 tps, lat 27.216 ms stddev 35.537, 0 failed
progress: 30.0 s, 1971.6 tps, lat 25.418 ms stddev 33.757, 0 failed
progress: 35.0 s, 1893.2 tps, lat 26.388 ms stddev 31.596, 0 failed
progress: 40.0 s, 1860.0 tps, lat 26.672 ms stddev 33.012, 0 failed
progress: 45.0 s, 1635.8 tps, lat 30.671 ms stddev 41.966, 0 failed
progress: 50.0 s, 1979.6 tps, lat 25.265 ms stddev 29.654, 0 failed
progress: 55.0 s, 1969.9 tps, lat 25.320 ms stddev 32.918, 0 failed
progress: 60.0 s, 1957.8 tps, lat 25.459 ms stddev 35.174, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 114058
number of failed transactions: 0 (0.000%)
latency average = 26.067 ms
latency stddev = 33.632 ms
initial connection time = 579.829 ms
tps = 1915.713896 (without initial connection time)
```


#### 4.9. fsync

```sh
postgres=# alter system set fsync=off;
ALTER SYSTEM
```
```sh
aduron@ubt-pg-aduron:~$ pgbench -h 192.168.56.10 -U postgres -p 5433 -d postgres -c 50 -j 2 -P 5 -T 60
Password:
pgbench (17.6 (Ubuntu 17.6-2.pgdg24.04+1), server 15.14 (Ubuntu 15.14-1.pgdg24.04+1))
starting vacuum...end.
progress: 5.0 s, 1775.2 tps, lat 25.292 ms stddev 32.046, 0 failed
progress: 10.0 s, 2063.8 tps, lat 24.206 ms stddev 32.154, 0 failed
progress: 15.0 s, 1973.4 tps, lat 25.390 ms stddev 31.411, 0 failed
progress: 20.0 s, 1844.9 tps, lat 27.059 ms stddev 34.551, 0 failed
progress: 25.0 s, 2006.9 tps, lat 24.942 ms stddev 33.150, 0 failed
progress: 30.0 s, 1972.2 tps, lat 25.278 ms stddev 30.869, 0 failed
progress: 35.0 s, 2013.5 tps, lat 24.871 ms stddev 34.589, 0 failed
progress: 40.0 s, 1910.9 tps, lat 26.183 ms stddev 33.067, 0 failed
progress: 45.0 s, 2047.2 tps, lat 24.407 ms stddev 31.303, 0 failed
progress: 50.0 s, 2060.2 tps, lat 24.197 ms stddev 28.498, 0 failed
progress: 55.0 s, 2021.6 tps, lat 24.776 ms stddev 29.583, 0 failed
progress: 60.0 s, 1906.0 tps, lat 26.122 ms stddev 33.755, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 50
number of threads: 2
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 118029
number of failed transactions: 0 (0.000%)
latency average = 25.224 ms
latency stddev = 32.150 ms
initial connection time = 474.155 ms
tps = 1980.515642 (without initial connection time)
```



### 5. написать какого значения tps удалось достичь, показать какие параметры в какие значения устанавливали и почему

Базобая производителность

|               perf               | tps  |
|----------------------------------|------|
| MIN | 1065.6 |
| AVG | 1264.144326 |
| MAX | 1345.4|


Изменения настроек:

|               name               | setting | unit |
|----------------------------------|---------|------|
| effective_cache_size             | **1047080** | 8kB |
| fsync                            | **off**   | |
| max_worker_processes             | **16**      | |
| shared_buffers                   | **65536**   | 8kB |
| synchronous_commit               | **off**     | |
| work_mem                         | **16384**   | kB|


Финальная производителность:

|               perf               | tps  |  улуч.  |  
|----------------------------------|------|---------|
| MIN | 1775.2      |        |
| AVG | 1980.515642 |        |
| MAX | 2063.8      |        |


Большая часть пользы происходит, как мы могли ожидать, из настроек *fsync* и *synchronous_commit*. Остальные настроики, в нашем контексте (ВМ на сообсвенном ноуте) почти не принесли никакой пользы, и стало очевидным что улучшить ситуацию не получится так как потолком является процессор хоста:




## Список использованных источников:

1. [TPC-B - Определение](https://tpc.org/tpcb/) 
2. [TPC-B - Подробности](https://jimgray.azurewebsites.net/benchmarkhandbook/tpcb.pdf)
3. [Значение effective_cache_size](https://wiki.etersoft.ru/PostgreSQL/Optimum#effective_cache_size)
