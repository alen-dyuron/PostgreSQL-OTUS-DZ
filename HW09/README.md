# Работа с join'ами, статистикой

## Цель

- знать и уметь применять различные виды join'ов
- строить и анализировать план выполенения запроса
- оптимизировать запрос
- уметь собирать и анализировать статистику для таблицы

## План

написания запросов с различными типами соединений
Необходимо:
1. Реализовать прямое соединение двух или более таблиц
2. Реализовать левостороннее (или правостороннее) соединение двух или более таблиц
3. Реализовать кросс соединение двух или более таблиц
4. Реализовать полное соединение двух или более таблиц
5. Реализовать запрос, в котором будут использованы разные типы соединений
6. Сделать комментарии на каждый запрос

К работе приложить структуру таблиц, для которых выполнялись соединения

> [!TIP]
> Задание со звездочкой*
> Придумайте 3 своих метрики на основе показанных представлений, отправьте их через ЛК, а так же поделитесь с коллегами в слаке


## Структура таблиц

> [!NOTE]
> Для выполнения этого ДЗ пользуемся кластером в.17 и создадим в нем небезызвестную [демо-базу от PostgresPro](https://postgrespro.ru/education/demodb). 

```sql
postgres@ubt-pg-aduron:~/demo$ ls -lrt
total 136036
-rwxrwxr-x 1 postgres postgres 139299795 Nov 23 20:55 demo-20250901-3m.sql.gz
postgres@ubt-pg-aduron:~/demo$ gunzip -c demo-20250901-3m.sql.gz | psql -U postgres
SET
[...]
CREATE DATABASE
You are now connected to database "demo" as user "postgres".
SET
[...]
```

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


### 1. Реализовать прямое соединение двух или более таблиц

Тут я выбрал простой вариант соединения между таблицами *tickets* и *bookings*
```sql
demo=# explain analyze
SELECT *
FROM bookings.tickets t
JOIN bookings.bookings b ON t.book_ref = b.book_ref;
                                                            QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=44906.09..178855.12 rows=2973862 width=73) (actual time=263.088..2015.357 rows=2973937 loops=1)
   Hash Cond: (t.book_ref = b.book_ref)
   ->  Seq Scan on tickets t  (cost=0.00..60482.62 rows=2973862 width=52) (actual time=0.062..236.829 rows=2973937 loops=1)
   ->  Hash  (cost=21168.93..21168.93 rows=1292893 width=21) (actual time=262.032..262.033 rows=1292893 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 5306kB
         ->  Seq Scan on bookings b  (cost=0.00..21168.93 rows=1292893 width=21) (actual time=0.023..90.145 rows=1292893 loops=1)
 Planning Time: 1.657 ms
[...]
 Execution Time: 2137.092 ms
(12 rows)
```

Также можно этого переписать вот таким образом, так как *book_ref* оказывается единственным соответсвующим столбцом для выполнения джойна: 
```sql
demo=# explain analyze
SELECT *
FROM bookings.tickets t
NATURAL JOIN bookings.bookings b;
                                                            QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=44906.09..178855.12 rows=2973862 width=66) (actual time=328.149..2153.294 rows=2973937 loops=1)
   Hash Cond: (t.book_ref = b.book_ref)
   ->  Seq Scan on tickets t  (cost=0.00..60482.62 rows=2973862 width=52) (actual time=6.569..322.725 rows=2973937 loops=1)
   ->  Hash  (cost=21168.93..21168.93 rows=1292893 width=21) (actual time=320.940..320.941 rows=1292893 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 5227kB
         ->  Seq Scan on bookings b  (cost=0.00..21168.93 rows=1292893 width=21) (actual time=0.076..115.509 rows=1292893 loops=1)
 Planning Time: 0.744 ms
[...]
 Execution Time: 2252.724 ms
(12 rows)
```

Немножко "ораклового" варианта, что на самом деле показывает одну и ту же картинку: 
```sql
demo=# explain analyze
SELECT  *
FROM
  bookings.tickets t,
  bookings.bookings b
where t.book_ref = b.book_ref;
                                                            QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=44906.09..178855.12 rows=2973862 width=73) (actual time=264.338..2006.812 rows=2973937 loops=1)
   Hash Cond: (t.book_ref = b.book_ref)
   ->  Seq Scan on tickets t  (cost=0.00..60482.62 rows=2973862 width=52) (actual time=0.224..237.172 rows=2973937 loops=1)
   ->  Hash  (cost=21168.93..21168.93 rows=1292893 width=21) (actual time=263.462..263.464 rows=1292893 loops=1)
         Buckets: 131072  Batches: 16  Memory Usage: 5306kB
         ->  Seq Scan on bookings b  (cost=0.00..21168.93 rows=1292893 width=21) (actual time=0.047..90.147 rows=1292893 loops=1)
 Planning Time: 0.479 ms
[...]
 Execution Time: 2105.108 ms
(12 rows)
```


### 2. Реализовать левостороннее (или правостороннее) соединение двух или более таблиц

Для этого выбираем 2 связанных таблиц, одна из которых не содержит полный набор соответсвующих строк.
```sql
demo=# select count(*) from segments s;
  count
---------
 3941249
(1 row)

demo=# select count(*) from boarding_passes;
  count
---------
 2463832
(1 row)

demo=# select count(*) from segments s where not exists (select 1 from boarding_passes where ticket_no = s.ticket_no and flight_id = s.flight_id);
  count
---------
 1477417
(1 row)

demo=# select count(*) from segments s where exists (select 1 from boarding_passes where ticket_no = s.ticket_no and flight_id = s.flight_id);
  count
---------
 2463832
(1 row)
```

Не очевидно, но *COALESCE* требует совпадающие типы данных для успешного применения
```sql
demo=# select s.ticket_no, s.flight_id, COALESCE(bp.boarding_time, 'not boarded yet!')
demo-# from segments s
demo-# left join boarding_passes bp
demo-# on s.ticket_no = bp.ticket_no and s.flight_id = bp.flight_id;
ERROR:  invalid input syntax for type timestamp with time zone: "not boarded yet!"
LINE 1: ...icket_no, s.flight_id, COALESCE(bp.boarding_time, 'not board...
                                                             ^
demo=# select s.ticket_no, s.flight_id, COALESCE(bp.boarding_time::text, 'not boarded yet!')
demo-# from segments s
demo-# left join boarding_passes bp
demo-# on s.ticket_no = bp.ticket_no and s.flight_id = bp.flight_id;
```

В данном случае нам необходимо преобразовать *boarding_time* в тип *text* 
```sql
demo=# select s.ticket_no, s.flight_id, COALESCE(bp.boarding_time::text, 'not boarded yet!')
from segments s
left join boarding_passes bp
on s.ticket_no = bp.ticket_no and s.flight_id = bp.flight_id
where s.flight_id = 2627;
   ticket_no   | flight_id |           coalesce
---------------+-----------+-------------------------------
 0005432053250 |      2627 | not boarded yet!
 0005432048234 |      2627 | 2025-10-15 13:31:01.726889+00
 0005432188482 |      2627 | 2025-10-15 13:22:58.249863+00
 0005432069941 |      2627 | 2025-10-15 13:35:07.573738+00
 0005433007946 |      2627 | 2025-10-15 13:24:24.751462+00
 0005433013173 |      2627 | 2025-10-15 13:23:04.167829+00
 0005432283448 |      2627 | 2025-10-15 13:22:46.956997+00
 0005432078496 |      2627 | 2025-10-15 13:28:46.423754+00
 0005433002560 |      2627 | 2025-10-15 13:36:58.464933+00
 0005432031045 |      2627 | 2025-10-15 13:18:44.557704+00
 0005432435188 |      2627 | 2025-10-15 13:22:36.492234+00
 0005432122288 |      2627 | 2025-10-15 13:26:05.897947+00
 0005432397344 |      2627 | 2025-10-15 13:20:57.629194+00
 0005432276721 |      2627 | 2025-10-15 13:26:24.150886+00
 0005432411617 |      2627 | 2025-10-15 13:37:22.263613+00
 0005433010876 |      2627 | 2025-10-15 13:27:29.117912+00
 0005432331052 |      2627 | 2025-10-15 13:33:36.318436+00
 0005433011234 |      2627 | 2025-10-15 13:23:53.014426+00
 0005432460848 |      2627 | 2025-10-15 13:32:06.942469+00
 0005432033628 |      2627 | 2025-10-15 13:23:20.172911+00
 0005432334594 |      2627 | 2025-10-15 13:22:15.634147+00
 0005432361229 |      2627 | 2025-10-15 13:31:37.482726+00
 0005432337177 |      2627 | 2025-10-15 13:30:05.595339+00
 0005432007766 |      2627 | not boarded yet!
 0005432277255 |      2627 | 2025-10-15 13:25:52.480875+00
 0005433007893 |      2627 | 2025-10-15 13:34:12.397657+00
 0005432397826 |      2627 | 2025-10-15 13:30:04.717793+00
 0005432375786 |      2627 | 2025-10-15 13:28:51.652511+00
 0005432227075 |      2627 | 2025-10-15 13:19:42.983277+00
 0005432286503 |      2627 | 2025-10-15 13:25:26.552614+00
 0005432052008 |      2627 | not boarded yet!
 0005433002586 |      2627 | 2025-10-15 13:20:37.179208+00
 0005432054697 |      2627 | 2025-10-15 13:36:36.096302+00
 0005432385657 |      2627 | 2025-10-15 13:28:46.154087+00
 0005432338354 |      2627 | 2025-10-15 13:27:55.453945+00
 0005432325482 |      2627 | 2025-10-15 13:29:05.419323+00
 0005432269158 |      2627 | 2025-10-15 13:32:56.962475+00
 0005433009002 |      2627 | 2025-10-15 13:21:46.313731+00
 0005432998607 |      2627 | 2025-10-15 13:32:24.28886+00
 0005432331983 |      2627 | 2025-10-15 13:31:16.933401+00
 0005432226872 |      2627 | 2025-10-15 13:18:56.4977+00
 0005432252209 |      2627 | 2025-10-15 13:35:57.091281+00
 0005432527540 |      2627 | 2025-10-15 13:34:16.027497+00
 0005432277245 |      2627 | 2025-10-15 13:23:12.398187+00
 0005432324114 |      2627 | 2025-10-15 13:31:37.388581+00
 0005433002313 |      2627 | 2025-10-15 13:33:03.665609+00
 0005432008536 |      2627 | not boarded yet!
 0005432488610 |      2627 | 2025-10-15 13:23:30.973709+00
 0005432220875 |      2627 | 2025-10-15 13:25:42.933836+00
 0005432494743 |      2627 | 2025-10-15 13:25:36.379132+00
[...]
```

Тем не менее EXPLAIN показывает, что тут исползуется RIGHT JOIN:
```sql
demo=# explain analyze
demo-# select s.ticket_no, s.flight_id, COALESCE(bp.boarding_time::text, 'not boarded yet!')
from segments s
left join boarding_passes bp
on s.ticket_no = bp.ticket_no and s.flight_id = bp.flight_id
where s.flight_id = 2627;
                                                                               QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Hash Right Join  (cost=285.63..1739.41 rows=244 width=50) (actual time=0.883..1.244 rows=404 loops=1)
   Hash Cond: (bp.ticket_no = s.ticket_no)
   ->  Index Scan using boarding_passes_flight_id_seat_no_key on boarding_passes bp  (cost=0.43..1450.83 rows=821 width=26) (actual time=0.060..0.272 rows=404 loops=1)
         Index Cond: (flight_id = 2627)
   ->  Hash  (cost=282.15..282.15 rows=244 width=18) (actual time=0.801..0.802 rows=404 loops=1)
         Buckets: 1024  Batches: 1  Memory Usage: 29kB
         ->  Index Scan using segments_flight_id_idx on segments s  (cost=0.43..282.15 rows=244 width=18) (actual time=0.014..0.491 rows=404 loops=1)
               Index Cond: (flight_id = 2627)
 Planning Time: 0.228 ms
 Execution Time: 1.275 ms
(10 rows)
```

Для того чтобы всё таки применить *LEFT JOIN*, нам надо отключить *enable_hashjoin*.
Тут очевидно, что такой план выполнения не был применен из-за значительно высшего значения *cost* 
```sql
demo=# SET enable_hashjoin = off;
SET
demo=# explain analyze
select s.ticket_no, s.flight_id, COALESCE(bp.boarding_time::text, 'not boarded yet!')
from segments s
left join boarding_passes bp
on s.ticket_no = bp.ticket_no and s.flight_id = bp.flight_id
where s.flight_id = 2627;
                                                                                  QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Merge Left Join  (cost=1782.40..1788.96 rows=244 width=50) (actual time=1.963..2.238 rows=404 loops=1)
   Merge Cond: (s.ticket_no = bp.ticket_no)
   ->  Sort  (cost=291.82..292.43 rows=244 width=18) (actual time=0.807..0.832 rows=404 loops=1)
         Sort Key: s.ticket_no
         Sort Method: quicksort  Memory: 40kB
         ->  Index Scan using segments_flight_id_idx on segments s  (cost=0.43..282.15 rows=244 width=18) (actual time=0.010..0.217 rows=404 loops=1)
               Index Cond: (flight_id = 2627)
   ->  Sort  (cost=1490.58..1492.63 rows=821 width=26) (actual time=1.149..1.168 rows=404 loops=1)
         Sort Key: bp.ticket_no
         Sort Method: quicksort  Memory: 43kB
         ->  Index Scan using boarding_passes_flight_id_seat_no_key on boarding_passes bp  (cost=0.43..1450.83 rows=821 width=26) (actual time=0.013..0.327 rows=404 loops=1)
               Index Cond: (flight_id = 2627)
 Planning Time: 0.229 ms
 Execution Time: 2.292 ms
(14 rows)
```

### 3. Реализовать кросс соединение двух или более таблиц

*CROSS JOIN* - просто декартое соединение строк из таблиц, то есть умножение. Результат соединения содержит все возможные комбинации:
```sql
demo=# select count(*) from airports;
 count
-------
  5501
(1 row)

demo=# select count(*) from airplanes;
 count
-------
    10
(1 row)

demo=# select count(*) from airports, airplanes;
 count
-------
 55010
(1 row)

demo=# explain analyse
demo-# select count(*) from airports, airplanes;
                                                                          QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=981.07..981.08 rows=1 width=8) (actual time=9.068..9.071 rows=1 loops=1)
   ->  Nested Loop  (cost=0.28..843.55 rows=55010 width=0) (actual time=0.052..6.749 rows=55010 loops=1)
         ->  Index Only Scan using airports_data_pkey on airports_data ml  (cost=0.28..154.80 rows=5501 width=0) (actual time=0.039..0.522 rows=5501 loops=1)
               Heap Fetches: 0
         ->  Materialize  (cost=0.00..1.15 rows=10 width=0) (actual time=0.000..0.000 rows=10 loops=5501)
               ->  Seq Scan on airplanes_data ml_1  (cost=0.00..1.10 rows=10 width=0) (actual time=0.009..0.010 rows=10 loops=1)
 Planning Time: 0.133 ms
 Execution Time: 9.100 ms
(8 rows)
```


### 4. Реализовать полное соединение двух или более таблиц

Полное соединение показывает все строки в обоих сторонах джойна, с дополнением *NULL* для несовпадающих строк.
```sql
demo=# explain analyse
select  a1.airplane_code, a1.seat_no, a1.fare_conditions, a2.airplane_code, a2.seat_no, a2.fare_conditions
from
   (select * from seats where airplane_code = '32N') a1
full join
   (select * from seats where airplane_code = '339') a2
on a1.seat_no = a2.seat_no;
                                                            QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------
 Hash Full Join  (cost=30.17..44.43 rows=281 width=30) (actual time=0.102..0.198 rows=411 loops=1)
   Hash Cond: (seats_1.seat_no = seats.seat_no)
   ->  Bitmap Heap Scan on seats seats_1  (cost=10.46..23.97 rows=281 width=15) (actual time=0.023..0.050 rows=281 loops=1)
         Recheck Cond: (airplane_code = '339'::bpchar)
         Heap Blocks: exact=3
         ->  Bitmap Index Scan on seats_pkey  (cost=0.00..10.38 rows=281 width=0) (actual time=0.020..0.020 rows=281 loops=1)
               Index Cond: (airplane_code = '339'::bpchar)
   ->  Hash  (cost=17.64..17.64 rows=166 width=15) (actual time=0.070..0.070 rows=166 loops=1)
         Buckets: 1024  Batches: 1  Memory Usage: 16kB
         ->  Bitmap Heap Scan on seats  (cost=5.56..17.64 rows=166 width=15) (actual time=0.037..0.048 rows=166 loops=1)
               Recheck Cond: (airplane_code = '32N'::bpchar)
               Heap Blocks: exact=1
               ->  Bitmap Index Scan on seats_pkey  (cost=0.00..5.52 rows=166 width=0) (actual time=0.026..0.026 rows=166 loops=1)
                     Index Cond: (airplane_code = '32N'::bpchar)
 Planning Time: 0.372 ms
 Execution Time: 0.244 ms
(16 rows)
```

Например, здесь сравниваем *seats* в самолетах 32N и 339, и показываем все строки независимо от их присутсвия на лева или на права джойна. 
```sql
demo=# select  a1.airplane_code, a1.seat_no, a1.fare_conditions, a2.airplane_code, a2.seat_no, a2.fare_conditions
demo-# from
demo-#    (select * from seats where airplane_code = '32N') a1
demo-# full join
demo-# (select * from seats where airplane_code = '339') a2
demo-# on a1.seat_no = a2.seat_no;
 airplane_code | seat_no | fare_conditions | airplane_code | seat_no | fare_conditions
---------------+---------+-----------------+---------------+---------+-----------------
 32N           | 1A      | Business        | 339           | 1A      | Business
 32N           | 1C      | Business        | 339           | 1C      | Business
               |         |                 | 339           | 1G      | Business
               |         |                 | 339           | 1J      | Business
 32N           | 2A      | Business        | 339           | 2A      | Business
 32N           | 2C      | Business        | 339           | 2C      | Business
               |         |                 | 339           | 2G      | Business
               |         |                 | 339           | 2J      | Business
 32N           | 3A      | Business        | 339           | 3A      | Business
 32N           | 3C      | Business        | 339           | 3C      | Business
               |         |                 | 339           | 3G      | Business
               |         |                 | 339           | 3J      | Business
 32N           | 4A      | Business        | 339           | 4A      | Business
 32N           | 4C      | Business        | 339           | 4C      | Business
               |         |                 | 339           | 4G      | Business
               |         |                 | 339           | 4J      | Business
 32N           | 5A      | Business        | 339           | 5A      | Business
 32N           | 5C      | Business        | 339           | 5C      | Business
               |         |                 | 339           | 5G      | Business
               |         |                 | 339           | 5J      | Business
 32N           | 6A      | Business        | 339           | 6A      | Business
 32N           | 6C      | Business        | 339           | 6C      | Business
               |         |                 | 339           | 6G      | Business
               |         |                 | 339           | 6J      | Business
 32N           | 7A      | Business        | 339           | 7A      | Business
 32N           | 7C      | Business        | 339           | 7C      | Business
               |         |                 | 339           | 7G      | Business
               |         |                 | 339           | 7J      | Business
 32N           | 8A      | Economy         | 339           | 8A      | Business
 32N           | 20A     | Economy         | 339           | 20A     | Comfort
 32N           | 20B     | Economy         | 339           | 20B     | Comfort
 32N           | 20C     | Economy         | 339           | 20C     | Comfort
[...]
               |         |                 | 339           | 57J     | Economy
               |         |                 | 339           | 58C     | Economy
               |         |                 | 339           | 58D     | Economy
               |         |                 | 339           | 58G     | Economy
 32N           | 8D      | Economy         |               |         |
 32N           | 19D     | Economy         |               |         |
 32N           | 17F     | Economy         |               |         |
 32N           | 30E     | Economy         |               |         |
 32N           | 26B     | Economy         |               |         |
 32N           | 20E     | Economy         |               |         |
 32N           | 9D      | Economy         |               |         |
 32N           | 28E     | Economy         |               |         |
 32N           | 16B     | Economy         |               |         |
 32N           | 8B      | Economy         |               |         |
 32N           | 28F     | Economy         |               |         |
 32N           | 13A     | Economy         |               |         |
 32N           | 15B     | Economy         |               |         |
[...]
 32N           | 26D     | Economy         |               |         |
 32N           | 29A     | Economy         |               |         |
 32N           | 9F      | Economy         |               |         |
 32N           | 24A     | Economy         |               |         |
 32N           | 29C     | Economy         |               |         |
[...]
(411 rows)
```

Для лучешо понимания того что мы получаем, можно ограничить результат, допустим, 30-м рядом. 
Видим, что в самолете *32N*, не существуют места _30G, 30H, 30J_, в то же время когда в самолете *339* не существует местo _30E_
```sql
demo=# select  a1.airplane_code, a1.seat_no, a1.fare_conditions, a2.airplane_code, a2.seat_no, a2.fare_conditions
 from
    (select * from seats where airplane_code = '32N' and seat_no like '30%') a1
 full join
 (select * from seats where airplane_code = '339' and seat_no like '30%') a2
 on a1.seat_no = a2.seat_no;
 airplane_code | seat_no | fare_conditions | airplane_code | seat_no | fare_conditions
---------------+---------+-----------------+---------------+---------+-----------------
 32N           | 30A     | Economy         | 339           | 30A     | Economy
 32N           | 30B     | Economy         | 339           | 30B     | Economy
 32N           | 30C     | Economy         | 339           | 30C     | Economy
 32N           | 30D     | Economy         | 339           | 30D     | Economy
 32N           | 30F     | Economy         | 339           | 30F     | Economy
               |         |                 | 339           | 30G     | Economy
               |         |                 | 339           | 30H     | Economy
               |         |                 | 339           | 30J     | Economy
 32N           | 30E     | Economy         |               |         |
(9 rows)
```


### 5. Реализовать запрос, в котором будут использованы разные типы соединений

В любом аеропорту, важно узнать во время посадки, каких пассажиров не хватает по вызову.
В данном случае это 
- те пассажиры с пустой (null) датой *boarding_time* для их *boarding_passes*
- для тех рейсов, которые находятся в состоянии *Boarding*
- детали для дополнительного вызова (*passenger_id, passenger_name*) можно узнавать в тавлице *tickets*

```sql
demo=# select distinct status from flights;
  status
-----------
 On Time
 Scheduled
 Departed
 Boarding
 Arrived
 Cancelled
 Delayed
(7 rows)
```

В итоге, можно запустить вот такой запрос:
```sql
demo=# select t.passenger_id, t.passenger_name, s.ticket_no, s.flight_id, COALESCE(bp.boarding_time::text, 'not boarded yet!')
from
  flights f
  join segments s
    on s.flight_id = f.flight_id
  join lateral (select passenger_id, passenger_name from tickets where ticket_no = s.ticket_no) as t on true
  left join boarding_passes bp
    on s.ticket_no = bp.ticket_no and s.flight_id = bp.flight_id
  where f.status = 'Boarding'
  and bp.boarding_time is null
  order by f.scheduled_departure desc;

 IN 3843629887351 | Akshay Reddy         | 0005433357347 |     11048 | not boarded yet!
 IN 3515839630186 | Sanjit Yadav         | 0005433361540 |     11048 | not boarded yet!
 IN 2429147761899 | Mahesh Singh         | 0005433383777 |     11048 | not boarded yet!
 IN 3502633162446 | Bina Kaur            | 0005433390273 |     11048 | not boarded yet!
 IN 0493956123791 | Mina Prasad          | 0005433467258 |     11048 | not boarded yet!
 IN 1021399125761 | Aanya Devi           | 0005433478410 |     11048 | not boarded yet!
 IN 9788541142927 | Jayanti Kakde        | 0005433992336 |     11048 | not boarded yet!
 IN 5080500153302 | Madhu Das            | 0005434002913 |     11048 | not boarded yet!
 IN 6832388146587 | Manorama Jhala       | 0005434002925 |     11048 | not boarded yet!
 IN 5078312101862 | Shobha Devi          | 0005434485542 |     11048 | not boarded yet!
 IN 5771216115312 | Kabita Chowdhuri     | 0005434552615 |     11048 | not boarded yet!
 IN 8235697213880 | Nandu Das            | 0005434561346 |     11048 | not boarded yet!
 IN 8839434164992 | Urmila Devi          | 0005434561975 |     11048 | not boarded yet!
 IN 7846027196079 | Pratibha Bharati     | 0005434595375 |     11048 | not boarded yet!
 IN 7745773180436 | Satya Chauhan        | 0005434595527 |     11048 | not boarded yet!
 IN 6562596160770 | Aanya Bhanu          | 0005434601619 |     11048 | not boarded yet!
 IN 1615912122945 | Sangita Kaur         | 0005434601622 |     11048 | not boarded yet!
 IN 3997378145777 | Sangeeta Devi        | 0005434613108 |     11048 | not boarded yet!
 IN 0906946820351 | Ramesh Singh         | 0005434632820 |     11048 | not boarded yet!
 IN 7916823151445 | Balu Patel           | 0005434632822 |     11048 | not boarded yet!
 IN 9602312141052 | Shefali Kaur         | 0005434637060 |     11048 | not boarded yet!
 IN 9112326189658 | Usha Konda           | 0005434641412 |     11048 | not boarded yet!
 IN 1547022908073 | Kala Chakraborty     | 0005434656232 |     11048 | not boarded yet!
 IN 7264575210252 | Gayatri Sharma       | 0005434696402 |     11048 | not boarded yet!
 IN 0944225197090 | Ganga Kaur           | 0005434711455 |     11048 | not boarded yet!
 IN 6486712182658 | Lata Sharma          | 0005434731394 |     11048 | not boarded yet!
 IN 3796756128280 | Pavan Paramar        | 0005434766106 |     11048 | not boarded yet!
 IN 3618530794442 | Basanta Patil        | 0005434785582 |     11048 | not boarded yet!
 IN 3430633922446 | Savitri Bai          | 0005434875987 |     11048 | not boarded yet!
 IN 9949432167606 | Rina Mandal          | 0005434917129 |     11048 | not boarded yet!
 IN 0121767212923 | Vitthal Kumar        | 0005434938750 |     11048 | not boarded yet!
 IN 8245155834004 | Anita Mondal         | 0005434938863 |     11048 | not boarded yet!
 IN 6272390138440 | Surjit Kumar         | 0005434940397 |     11048 | not boarded yet!
 IN 0913925150475 | Aarav Kumar          | 0005434942027 |     11048 | not boarded yet!
 IN 4691707389190 | Bhaskar Das          | 0005434945081 |     11048 | not boarded yet!
 IN 4630465163663 | Purnima Mondal       | 0005434946091 |     11048 | not boarded yet!
 IN 8356267919464 | Urmila Kumari        | 0005434946164 |     11048 | not boarded yet!
 IN 5438384200825 | Rajesh Kumar         | 0005434946289 |     11048 | not boarded yet!
 IN 9434907186957 | Arjun Mondal         | 0005434953451 |     11048 | not boarded yet!
 IN 2854304437051 | Vinod Ram            | 0005434954396 |     11048 | not boarded yet!
 IN 5441542188334 | Dharmendra Singh     | 0005434955606 |     11048 | not boarded yet!
 IN 3355612554349 | Bhaskar Das          | 0005434955136 |     11048 | not boarded yet!
 IN 5277595580052 | Babli Devi           | 0005434956874 |     11048 | not boarded yet!
 IN 0547295103061 | Girija Kumari        | 0005434956969 |     11048 | not boarded yet!
 IN 6187474128246 | Ram Kumar            | 0005434958735 |     11048 | not boarded yet!
 IN 1421008933691 | Gangaram Chauhan     | 0005434958741 |     11048 | not boarded yet!
 IN 1529322236426 | Rekha Mallik         | 0005434958746 |     11048 | not boarded yet!
 IN 9719935779856 | Kumari Bharavad      | 0005434958359 |     11048 | not boarded yet!
 IN 5800697127226 | Sanjit Maiiti        | 0005434958952 |     11048 | not boarded yet!
 IN 2100220308443 | Narayan Das          | 0005434958959 |     11048 | not boarded yet!
(240 rows)
```

Здесь *explain* показывает вот такую картинку:
```sql
demo=# explain analyze
demo-# select t.passenger_id, t.passenger_name, s.ticket_no, s.flight_id, COALESCE(bp.boarding_time::text, 'not boarded yet!')
from
  flights f
  join segments s
    on s.flight_id = f.flight_id
  join lateral (select passenger_id, passenger_name from tickets where ticket_no = s.ticket_no) as t on true
  left join boarding_passes bp
    on s.ticket_no = bp.ticket_no and s.flight_id = bp.flight_id
  where f.status = 'Boarding'
  and bp.boarding_time is null
  order by f.scheduled_departure desc;
                                                                            QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=1991.99..1992.01 rows=9 width=88) (actual time=13.343..13.391 rows=240 loops=1)
   Sort Key: f.scheduled_departure DESC
   Sort Method: quicksort  Memory: 47kB
   ->  Nested Loop  (cost=1.29..1991.85 rows=9 width=88) (actual time=0.712..13.116 rows=240 loops=1)
         ->  Nested Loop Left Join  (cost=0.86..1987.39 rows=9 width=34) (actual time=0.689..9.241 rows=240 loops=1)
               Filter: (bp.boarding_time IS NULL)
               Rows Removed by Filter: 330
               ->  Nested Loop  (cost=0.43..1629.84 rows=725 width=26) (actual time=0.609..2.285 rows=570 loops=1)
                     ->  Seq Scan on flights f  (cost=0.00..475.98 rows=4 width=12) (actual time=0.593..1.651 rows=4 loops=1)
                           Filter: (status = 'Boarding'::text)
                           Rows Removed by Filter: 21754
                     ->  Index Scan using segments_flight_id_idx on segments s  (cost=0.43..286.00 rows=247 width=18) (actual time=0.008..0.130 rows=142 loops=4)
                           Index Cond: (flight_id = f.flight_id)
               ->  Index Scan using boarding_passes_pkey on boarding_passes bp  (cost=0.43..0.48 rows=1 width=26) (actual time=0.011..0.011 rows=1 loops=570)
                     Index Cond: ((ticket_no = s.ticket_no) AND (flight_id = s.flight_id))
         ->  Index Scan using tickets_pkey on tickets  (cost=0.43..0.49 rows=1 width=44) (actual time=0.015..0.015 rows=1 loops=240)
               Index Cond: (ticket_no = s.ticket_no)
 Planning Time: 1.341 ms
 Execution Time: 13.558 ms
(19 rows)
```


### 6. Сделать комментарии на каждый запрос

> [!NOTE]
> 2. В постпресе, видимо необходимо для замены *NULL* на что-нибудь другое, пользоваться *COLEASCE*, что в свой очередь заставляет преобразовать входные данные. Это логично, но странновато выгладит по сравнению, например, с функцией *NLV* (доступной в Oracle), которыая рассматривает только значение *NULL* без учета типа данных.

> [!NOTE]
> 4. Полное соединение показывает все строки в обоих сторонах джойна с учётом значения *NULL*, что очень полезно для полного сравнивания и обнаружение *совпадующих и несовпадающих* данных.

> [!NOTE]
> 5. Тут *LATERAL* джойн преврашается в обычный *Nested Loop*. Я ещё не нашел способ заставить кластер правильно использовать тот или иной вид джойна. 



## Ресурсы 

1. [PostgresPro Demo DB](https://postgrespro.ru/education/demodb)