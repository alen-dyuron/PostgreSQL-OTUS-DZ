# Работа с индексами

## Цель

- знать и уметь применять основные виды индексов PostgreSQL
- строить и анализировать план выполнения запроса
- уметь оптимизировать запросы для с использованием индексов

## План

Создать индексы на БД, которые ускорят доступ к данным.
В данном задании тренируются навыки:

определения узких мест
написания запросов для создания индекса
оптимизации
Необходимо:

1. Создать индекс к какой-либо из таблиц вашей БД
2. Прислать текстом результат команды explain, в которой используется данный индекс
3. Реализовать индекс для полнотекстового поиска
4. Реализовать индекс на часть таблицы или индекс на поле с функцией
5. Создать индекс на несколько полей
6. Написать комментарии к каждому из индексов
7. Описать что и как делали и с какими проблемами столкнулись


## Структура таблиц

> [!NOTE]
> Для выполнения этого ДЗ снова пользуемся кластером в.17 [демо-базой от PostgresPro](https://postgrespro.ru/education/demodb). 


![VM](img/dz9-1.png)

```sql
postgres@ubt-pg-aduron:~/demo$ psql -U postgres -d demo
psql (17.6 (Ubuntu 17.6-2.pgdg24.04+1))
Type "help" for help.

demo=# \d+
                                                             List of relations
  Schema  |         Name          |   Type   |  Owner   | Persistence | Access method |    Size    |              Description
----------+-----------------------+----------+----------+-------------+---------------+------------+----------------------------------------
 bookings | airplanes             | view     | postgres | permanent   |               | 0 bytes    | Airplanes
 bookings | airplanes_data        | table    | postgres | permanent   | heap          | 16 kB      | Airplanes (internal multilingual data)
 bookings | airports              | view     | postgres | permanent   |               | 0 bytes    | Airports
 bookings | airports_data         | table    | postgres | permanent   | heap          | 1280 kB    | Airports (internal multilingual data)
 bookings | boarding_passes       | table    | postgres | permanent   | heap          | 160 MB     | Boarding passes
 bookings | bookings              | table    | postgres | permanent   | heap          | 64 MB      | Bookings
 bookings | flights               | table    | postgres | permanent   | heap          | 1672 kB    | Flights
 bookings | flights_flight_id_seq | sequence | postgres | permanent   |               | 8192 bytes |
 bookings | routes                | table    | postgres | permanent   | heap          | 224 kB     | Routes
 bookings | seats                 | table    | postgres | permanent   | heap          | 120 kB     | Seats
 bookings | segments              | table    | postgres | permanent   | heap          | 257 MB     | Flight segment (leg)
 bookings | tickets               | table    | postgres | permanent   | heap          | 240 MB     | Tickets
 bookings | timetable             | view     | postgres | permanent   |               | 0 bytes    | Detailed info about flights
(13 rows)
```


## Выполнение

### 1. Создать индекс к какой-либо из таблиц вашей БД

Будем здесь работать с таблицей *tickets*
```sql
demo=# select * from tickets limit 10;
   ticket_no   | book_ref |   passenger_id   |  passenger_name   | outbound
---------------+----------+------------------+-------------------+----------
 0005432000000 | RBUUIQ   | IT 2425980678984 | Ilaria Cazzaniga  | t
 0005432000001 | 2EW1SQ   | CL 7793846138778 | Claudio Gonzalez  | t
 0005432000003 | RBUUIQ   | IT 2425980678984 | Ilaria Cazzaniga  | f
 0005432000002 | Y4KNLB   | IN 6055838167316 | Sunita Mal        | t
 0005432000004 | GGY5EU   | DE 4384341116867 | Karl-Heinz Arndt  | t
 0005432000005 | 6TAS39   | DE 0926458219327 | Dietmar Franz     | t
 0005432000006 | KOS1KJ   | US 1903569888046 | Jamie Jackson     | t
 0005432000007 | MJUZ2D   | IN 9845886166493 | Smita Chand       | t
 0005432000009 | CFSWW6   | RU 2408782196542 | Natalya Filippova | t
 0005432000008 | YY3YVH   | CN 3545368122753 | Zhiming Hou       | t
(10 rows)
```

В базе демо, нет индексов на поле *passenger_name*, соответственно зарпросы с такими филтрами ходят по плану типа FTS (параллелно)
```sql
demo=# explain analyze
demo-# select * from tickets where passenger_name = 'Dietmar Franz';
                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..47234.96 rows=21 width=52) (actual time=1.064..896.190 rows=2 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on tickets  (cost=0.00..46232.86 rows=9 width=52) (actual time=583.838..881.243 rows=1 loops=3)
         Filter: (passenger_name = 'Dietmar Franz'::text)
         Rows Removed by Filter: 991312
 Planning Time: 0.270 ms
 Execution Time: 896.250 ms
(8 rows)
```

Создадим индекс на *passenger_name* под названием *tickets_passenger_name*:
```sql
demo=# CREATE INDEX tickets_passenger_name ON bookings.tickets USING btree (passenger_name);
CREATE INDEX
```


### 2. Прислать текстом результат команды explain, в которой используется данный индекс


После создания видно, что наш индекс *tickets_passenger_name* исползуется, а при этом *cost* резко уменшается 
```sql
demo=# explain analyze
demo-# select * from tickets where passenger_name = 'Dietmar Franz';
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on tickets  (cost=4.59..87.21 rows=21 width=52) (actual time=0.188..0.190 rows=2 loops=1)
   Recheck Cond: (passenger_name = 'Dietmar Franz'::text)
   Heap Blocks: exact=1
   ->  Bitmap Index Scan on tickets_passenger_name  (cost=0.00..4.59 rows=21 width=0) (actual time=0.174..0.174 rows=2 loops=1)
         Index Cond: (passenger_name = 'Dietmar Franz'::text)
 Planning Time: 0.491 ms
 Execution Time: 0.220 ms
(7 rows)
```


### 3. Реализовать индекс для полнотекстового поиска

Если запустить такой запрос с полнотекстовым поиском, снова встрешаем *Seq Scan* без использования индекса
```sql
demo=# explain analyze
demo-# SELECT * from tickets where passenger_name like 'Dietmar%';
                                                        QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..47262.36 rows=291 width=52) (actual time=0.750..164.880 rows=339 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on tickets  (cost=0.00..46233.26 rows=121 width=52) (actual time=2.992..152.890 rows=113 loops=3)
         Filter: (passenger_name ~~ 'Dietmar%'::text)
         Rows Removed by Filter: 991199
 Planning Time: 0.729 ms
 Execution Time: 164.948 ms
(8 rows)
```

Для частичной поддержки такого пойска с индексом, нужно добавить *text_pattern_ops* во время создания btree-индекса вот таким образом:
```sql
Drop index tickets_passenger_name
CREATE INDEX tickets_passenger_name ON bookings.tickets USING btree (passenger_name text_pattern_ops);
```

Это полволит *частично* решать проблему...
```sql
demo=# explain analyze
demo-# SELECT * from tickets where passenger_name like 'Dietmar%';
                                                             QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using tickets_passenger_name on tickets  (cost=0.43..8.45 rows=291 width=52) (actual time=0.207..6.607 rows=339 loops=1)
   Index Cond: ((passenger_name ~>=~ 'Dietmar'::text) AND (passenger_name ~<~ 'Dietmas'::text))
   Filter: (passenger_name ~~ 'Dietmar%'::text)
 Planning Time: 0.788 ms
 Execution Time: 6.695 ms
(5 rows)
```

Но видимо не полностю. 
```sql
demo=# explain analyze
demo-# SELECT * from tickets where passenger_name like '%ietmar%';
                                                        QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..47262.36 rows=291 width=52) (actual time=0.787..224.461 rows=339 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on tickets  (cost=0.00..46233.26 rows=121 width=52) (actual time=2.979..208.655 rows=113 loops=3)
         Filter: (passenger_name ~~ '%ietmar%'::text)
         Rows Removed by Filter: 991199
 Planning Time: 0.232 ms
 Execution Time: 224.550 ms
(8 rows)
```

Для полнотекстового поиска видимо придётся установить расширение *pg_trgm* и пересоздать индекс, используя *{gin + gin_trgm_ops}* вместо *{btree + text_pattern_ops}*
```sql
demo=# create extension pg_trgm;
CREATE EXTENSION
demo=# Drop index tickets_passenger_name;
DROP INDEX
demo=# CREATE INDEX tickets_passenger_name ON bookings.tickets USING gin (passenger_name gin_trgm_ops);
CREATE INDEX
demo=# explain analyze
demo-# SELECT * from tickets where passenger_name like '%ietmar%';
                                                             QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on tickets  (cost=78.05..1157.19 rows=291 width=52) (actual time=3.894..4.155 rows=339 loops=1)
   Recheck Cond: (passenger_name ~~ '%ietmar%'::text)
   Heap Blocks: exact=203
   ->  Bitmap Index Scan on tickets_passenger_name  (cost=0.00..77.97 rows=291 width=0) (actual time=3.852..3.853 rows=339 loops=1)
         Index Cond: (passenger_name ~~ '%ietmar%'::text)
 Planning Time: 0.962 ms
 Execution Time: 4.205 ms
(7 rows)
```


### 4. Реализовать индекс на часть таблицы или индекс на поле с функцией

Ещё проблемой является регистрозависимый поиск. Допустим, как запустить следующий запрос с учетом геристра? вот так? 
```sql
demo=# explain analyze
demo-# select * from tickets where passenger_name = 'dietmar franz';
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on tickets  (cost=4.59..87.21 rows=21 width=52) (actual time=0.045..0.045 rows=0 loops=1)
   Recheck Cond: (passenger_name = 'dietmar franz'::text)
   ->  Bitmap Index Scan on tickets_passenger_name  (cost=0.00..4.59 rows=21 width=0) (actual time=0.039..0.039 rows=0 loops=1)
         Index Cond: (passenger_name = 'dietmar franz'::text)
 Planning Time: 0.093 ms
 Execution Time: 0.067 ms
(6 rows)
```

Ну неть:
```sql
demo=# select * from tickets where passenger_name = 'dietmar franz';
 count
-------
     0
(1 row)
```

Вот так? ну видимо да...
```sql
demo=# select * from tickets where upper(passenger_name) = upper('dietmar franz');
   ticket_no   | book_ref |   passenger_id   | passenger_name | outbound
---------------+----------+------------------+----------------+----------
 0005432000005 | 6TAS39   | DE 0926458219327 | Dietmar Franz  | t
 0005432000014 | 6TAS39   | DE 0926458219327 | Dietmar Franz  | f
(2 rows)
```

Но при этом, индекс не исползуется из-за присутствия функции для преобразования *passenger_name*:
```sql
demo=# explain analyze
demo-# select * from tickets where upper(passenger_name) = upper('dietmar franz')
demo-# ;
                                                         QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..51818.11 rows=14870 width=52) (actual time=0.872..469.860 rows=2 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on tickets  (cost=0.00..49331.11 rows=6196 width=52) (actual time=304.443..459.887 rows=1 loops=3)
         Filter: (upper(passenger_name) = 'DIETMAR FRANZ'::text)
         Rows Removed by Filter: 991312
 Planning Time: 0.358 ms
 Execution Time: 469.893 ms
(8 rows)
```

Тогда можно создать такой индекс с функцией:
```sql
demo=# CREATE INDEX tickets_passenger_uppername ON bookings.tickets USING btree (upper(passenger_name));
CREATE INDEX
demo=# explain analyze
demo-# select * from tickets where upper(passenger_name) = upper('dietmar franz');
                                                                QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on tickets  (cost=227.67..25929.75 rows=14870 width=52) (actual time=0.120..0.122 rows=2 loops=1)
   Recheck Cond: (upper(passenger_name) = 'DIETMAR FRANZ'::text)
   Heap Blocks: exact=1
   ->  Bitmap Index Scan on tickets_passenger_uppername  (cost=0.00..223.95 rows=14870 width=0) (actual time=0.109..0.109 rows=2 loops=1)
         Index Cond: (upper(passenger_name) = 'DIETMAR FRANZ'::text)
 Planning Time: 0.649 ms
 Execution Time: 0.151 ms
(7 rows)

demo=# select * from tickets where upper(passenger_name) = upper('dietmar franz');
   ticket_no   | book_ref |   passenger_id   | passenger_name | outbound
---------------+----------+------------------+----------------+----------
 0005432000005 | 6TAS39   | DE 0926458219327 | Dietmar Franz  | t
 0005432000014 | 6TAS39   | DE 0926458219327 | Dietmar Franz  | f
(2 rows)
```
Прекрасно)


### 5. Создать индекс на несколько полей

В этот раз работаем с таблицей *flights*:
```sql
demo=# select * from flights limit 10;
 flight_id | route_no |  status   |  scheduled_departure   |   scheduled_arrival    |       actual_departure        |        actual_arrival
-----------+----------+-----------+------------------------+------------------------+-------------------------------+-------------------------------
        72 | PG0218   | Arrived   | 2025-10-01 10:55:00+00 | 2025-10-01 13:50:00+00 | 2025-10-01 10:59:28.291593+00 | 2025-10-01 13:56:27.021882+00
     12136 | PG0366   | Scheduled | 2025-12-07 02:55:00+00 | 2025-12-07 03:50:00+00 |                               |
         2 | PG0247   | Arrived   | 2025-10-01 00:20:00+00 | 2025-10-01 03:25:00+00 | 2025-10-01 00:24:49.838375+00 | 2025-10-01 03:30:44.057125+00
     12154 | PG0385   | Scheduled | 2025-12-07 05:45:00+00 | 2025-12-07 07:55:00+00 |                               |
     12160 | PG0550   | Scheduled | 2025-12-07 06:45:00+00 | 2025-12-07 09:35:00+00 |                               |
     12165 | PG0190   | Scheduled | 2025-12-07 07:15:00+00 | 2025-12-07 09:30:00+00 |                               |
        35 | PG0035   | Arrived   | 2025-10-01 06:15:00+00 | 2025-10-01 07:05:00+00 | 2025-10-01 06:22:06.667592+00 | 2025-10-01 07:12:08.286108+00
        89 | PG0039   | Arrived   | 2025-10-01 13:00:00+00 | 2025-10-01 17:30:00+00 | 2025-10-01 13:08:08.884115+00 | 2025-10-01 17:37:57.969794+00
       112 | PG0248   | Arrived   | 2025-10-01 15:05:00+00 | 2025-10-01 18:10:00+00 | 2025-10-01 15:07:13.217186+00 | 2025-10-01 18:11:39.956769+00
        64 | PG0182   | Arrived   | 2025-10-01 10:10:00+00 | 2025-10-01 11:00:00+00 | 2025-10-01 10:14:33.288235+00 | 2025-10-01 11:05:25.915342+00
(10 rows)
```

Ищем *flights* со статусом *Arrived* и разными фильтрами на полях *actual_departure* и *actual_arrival*:
```sql
demo=# explain analyze
demo-# select * from flights where status = 'Arrived' and actual_departure > '2025-10-01 06:00:00.000000+00' and actual_arrival < '2025-10-01 08:00:00.000000+00';
                                                                                          QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Seq Scan on flights  (cost=0.00..584.77 rows=11 width=51) (actual time=0.037..17.668 rows=5 loops=1)
   Filter: ((actual_departure > '2025-10-01 06:00:00+00'::timestamp with time zone) AND (actual_arrival < '2025-10-01 08:00:00+00'::timestamp with time zone) AND (status = 'Arrived'::text))
   Rows Removed by Filter: 21753
 Planning Time: 0.398 ms
 Execution Time: 17.696 ms
(5 rows)
```

Создадим вот такой индекс, и проверим что теперь испоьзуется во время выполнения предыдущего запроса:
```sql
demo=# create index flights_status_dep_arr on bookings.flights using btree (status, actual_departure, actual_arrival);
CREATE INDEX
demo=# explain analyze
demo-# select * from flights where status = 'Arrived' and actual_departure > '2025-10-01 06:00:00.000000+00' and actual_arrival < '2025-10-01 08:00:00.000000+00';
                                                                                            QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using flights_status_dep_arr on flights  (cost=0.29..162.59 rows=11 width=51) (actual time=0.323..3.928 rows=5 loops=1)
   Index Cond: ((status = 'Arrived'::text) AND (actual_departure > '2025-10-01 06:00:00+00'::timestamp with time zone) AND (actual_arrival < '2025-10-01 08:00:00+00'::timestamp with time zone))
 Planning Time: 0.703 ms
 Execution Time: 3.964 ms
(4 rows)
```

### 6. Написать комментарии к каждому из индексов


> [!NOTE]
> Объяснения уже находятся в разделах 1-5 :-)


### 7. Описать что и как делали и с какими проблемами столкнулись

Вроде проблем нет, но по сравнению с другими СУБД, это удивительно что создание неких вариантов индексов (допустим, для полнотекстового поиска) требует установки расширения, когда другие СУБД позволяют создать такие индексы по умолчанию. 


## Ресурсы 

1. [PostgresPro Demo DB](https://postgrespro.ru/education/demodb)