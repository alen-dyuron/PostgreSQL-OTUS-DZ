# Бэкапы

## Цель

- Создать триггер для поддержки витрины в актуальном состоянии.

## План

1. Создание БД
2. Инициализация витрины
3. Создание функции для триггера
4. Создание триггера
5. Примеры выполнения
6. Вопрос со *


## Выполнение

### 1. Создание тестовой БД

Создадим схему
```sql
test_db=# DROP SCHEMA IF EXISTS pract_functions CASCADE;
CREATE SCHEMA pract_functions;
NOTICE:  schema "pract_functions" does not exist, skipping
DROP SCHEMA
CREATE SCHEMA
test_db=# SET search_path = pract_functions, public;
SET
test_db=# CREATE TABLE goods
(
    goods_id    integer PRIMARY KEY,
    good_name   varchar(63) NOT NULL,
    good_price  numeric(12, 2) NOT NULL CHECK (good_price > 0.0)
);
INSERT INTO goods (goods_id, good_name, good_price)
VALUES  (1, 'Спички хозайственные', .50),
                (2, 'Автомобиль Ferrari FXX K', 185000000.01);
CREATE TABLE
INSERT 0 2
test_db=# CREATE TABLE sales
(
    sales_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    good_id     integer REFERENCES goods (goods_id),
    sales_time  timestamp with time zone DEFAULT now(),
    sales_qty   integer CHECK (sales_qty > 0)
);

INSERT INTO sales (good_id, sales_qty) VALUES (1, 10), (1, 1), (1, 120), (2, 1);
CREATE TABLE
INSERT 0 4
```

### 2. Инициализация витрины


> [!NOTE]
> Если хотим сохранить порядок выполнения, и создать триггер попозже, нам приходится инициализировать *good_sum_mart* с текущим результатом отсчета

```sql
test_db=# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;
        good_name         |     sum
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 rows)
```

```sql
test_db=# insert into good_sum_mart (good_name,sum_sale)
test_db-# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;
INSERT 0 2
```


### 3. Создание функции для триггера

Создадим эту функцию
```sql
CREATE OR REPLACE FUNCTION tf_update_accounting()
RETURNS trigger
AS
$$
DECLARE
	new_sale record;
	old_sale record;
BEGIN

	CREATE OR REPLACE PROCEDURE mergeinsert(p_new_sale record) AS $mergeinsert$
	BEGIN
		MERGE INTO good_sum_mart m
		USING ( select p_new_sale.good_id, g.good_name, p_new_sale.sales_qty, g.good_price
				from goods g where g.goods_id = p_new_sale.good_id) s
		ON m.good_name = s.good_name
		WHEN MATCHED THEN  /* already exists, updating the sum */
		  UPDATE SET sum_sale = sum_sale + (s.sales_qty * s.good_price)
		WHEN NOT MATCHED THEN  /* non-existent, we add it */
		  INSERT (good_name, sum_sale)
		  VALUES (s.good_name, (s.sales_qty * s.good_price));
	END;
	$mergeinsert$ language plpgsql;
	
	CREATE OR REPLACE PROCEDURE mergedelete(p_old_sale record) AS $mergedelete$
	BEGIN
		MERGE INTO good_sum_mart m
		USING ( select p_old_sale.good_id, g.good_name, p_old_sale.sales_qty, g.good_price
				from goods g where g.goods_id = p_old_sale.good_id) s
		ON m.good_name = s.good_name
		WHEN MATCHED AND m.sum_sale = (s.sales_qty * s.good_price) THEN /* this sale represented the whole amount */
		  DELETE
		WHEN MATCHED AND m.sum_sale > (s.sales_qty * s.good_price) THEN /* this sale represented only a part that we remove */
		  UPDATE SET sum_sale = sum_sale - (s.sales_qty * s.good_price);
	END;
	$mergedelete$ language plpgsql;

	IF TG_LEVEL = 'ROW' THEN
		CASE TG_OP
			WHEN 'INSERT' THEN
				new_sale = NEW;
				call mergeinsert(new_sale);
				
			WHEN 'DELETE' THEN
				old_sale = OLD;
				call mergedelete(old_sale);

			WHEN 'UPDATE' THEN
				old_sale = OLD;
				new_sale = NEW;

				IF old_sale.good_id = new_sale.good_id THEN 
					/* For the new_sale, we do an mergeinsert
						- Will update if the good_id has not changed. 
						- Will insert (if exists) or update if the good_id has changed
						- If the good has not changed, the old qty should be substracted from the new
					*/
					new_sale.sales_qty = new_sale.sales_qty - old_sale.sales_qty;
				ELSE
					/* If the good_id has changed we do complementary mergedelete of the old_sale
						- Will do an update if this item still has sold quantities
						- Will do a delete otherwise
					*/
					call mergedelete(old_sale);
				END IF;
				call mergeinsert(new_sale);

		END CASE;
	
	ELSE
		/* When sales is emptied, we simply empty the accounting table*/
		CASE TG_OP
			WHEN 'TRUNCATE' THEN
				TRUNCATE TABLE good_sum_mart;
		END CASE;
	END IF;

	return null;

EXCEPTION
	WHEN OTHERS THEN
		RAISE NOTICE 'ERROR CODE: %. MESSAGE TEXT: %', SQLSTATE, SQLERRM;
END;
$$  LANGUAGE plpgsql
```

Функция имеет такие особености
- способна выполняться для триггеров *for each row* а также для триггеров *for each statement*
- управляет всеми событиями, выполняемыми в исходной таблице включая *truncate* 
- Включает многоразовые процедуры на основании *merge* с целю сохрашения кода и уменшения количества запросов, которые будут выполнятся


### 4. Создание триггера

Создадим триггеры на основании функции *tf_update_accounting*:

```sql
CREATE TRIGGER trg_update_accounting
AFTER INSERT OR UPDATE OR DELETE 
ON sales
FOR EACH ROW
EXECUTE FUNCTION tf_update_accounting();
```

```sql
CREATE TRIGGER trg_empty_accounting
BEFORE TRUNCATE
ON sales
FOR EACH STATEMENT
EXECUTE FUNCTION tf_update_accounting();
```


### 5. Примеры выполнения

Сначала добавим более выгодные для покупателей товары

```sql
test_db=# INSERT INTO goods (goods_id, good_name, good_price)
VALUES
(3, 'LTD HEX-200 Signature Nergal', 5000),
(4, 'Билет консерта Rammstein', 300),
(5, 'Билет консерта Nagart МСК', 90),
(6, 'Fender David Gilmour Signature', 4300)
;
INSERT 0 4

test_db=# select * from goods;
 goods_id |           good_name            |  good_price
----------+--------------------------------+--------------
        1 | Спички хозайственные           |         0.50
        2 | Автомобиль Ferrari FXX K       | 185000000.01
        3 | LTD HEX-200 Signature Nergal   |      5000.00
        4 | Билет консерта Rammstein       |       300.00
        5 | Билет консерта Nagart МСК      |        90.00
        6 | Fender David Gilmour Signature |      4300.00
(6 rows)
```

> [!NOTE]
> После каждой операции будем проверять и сравнивать результатов запрос отчета и содежимое витрины *good_sum_mart*

#### INSERTs

```sql
-- Новые продажи

test_db=# INSERT INTO sales (good_id, sales_qty)
VALUES (3, 1), (3, 1), (3, 2);
INSERT 0 3
test_db=# INSERT INTO sales (good_id, sales_qty)
VALUES (4, 1), (4, 2), (4, 5), (4, 20), (4, 100);
INSERT 0 5
test_db=# INSERT INTO sales (good_id, sales_qty)
VALUES (5, 1), (5, 3), (5, 5), (5, 7), (5, 9);
INSERT 0 5
test_db=# INSERT INTO sales (good_id, sales_qty)
VALUES (6, 2), (6, 1);
INSERT 0 2
```

```sql
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
order by 1;

select * from good_sum_mart order by 1;


           good_name            |     sum
--------------------------------+--------------
 Fender David Gilmour Signature |     12900.00
 LTD HEX-200 Signature Nergal   |     20000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      2250.00
 Билет консерта Rammstein       |     38400.00
 Спички хозайственные           |        65.50
(6 rows)

           good_name            |   sum_sale
--------------------------------+--------------
 Fender David Gilmour Signature |     12900.00
 LTD HEX-200 Signature Nergal   |     20000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      2250.00
 Билет консерта Rammstein       |     38400.00
 Спички хозайственные           |        65.50
(6 rows)
```

#### DELETEs

```sql
test_db=# select * from sales;
 sales_id | good_id |          sales_time           | sales_qty
----------+---------+-------------------------------+-----------
        1 |       1 | 2025-12-24 07:20:20.229051+00 |        10
        2 |       1 | 2025-12-24 07:20:20.229051+00 |         1
        3 |       1 | 2025-12-24 07:20:20.229051+00 |       120
        4 |       2 | 2025-12-24 07:20:20.229051+00 |         1
        5 |       3 | 2025-12-24 07:20:39.142536+00 |         1
        6 |       3 | 2025-12-24 07:20:39.142536+00 |         1
        7 |       3 | 2025-12-24 07:20:39.142536+00 |         2
        8 |       4 | 2025-12-24 07:20:51.44151+00  |         1
        9 |       4 | 2025-12-24 07:20:51.44151+00  |         2
       10 |       4 | 2025-12-24 07:20:51.44151+00  |         5
       11 |       4 | 2025-12-24 07:20:51.44151+00  |        20
       12 |       4 | 2025-12-24 07:20:51.44151+00  |       100
       13 |       5 | 2025-12-24 07:20:55.642807+00 |         1
       14 |       5 | 2025-12-24 07:20:55.642807+00 |         3
       15 |       5 | 2025-12-24 07:20:55.642807+00 |         5
       16 |       5 | 2025-12-24 07:20:55.642807+00 |         7
       17 |       5 | 2025-12-24 07:20:55.642807+00 |         9
       18 |       6 | 2025-12-24 07:20:59.673709+00 |         2
       19 |       6 | 2025-12-24 07:20:59.673709+00 |         1
(19 rows)

-- Удаление (отменение) продажа

test_db=# DELETE from sales where sales_id = 10 ;
DELETE 1
test_db=# select * from sales;
 sales_id | good_id |          sales_time           | sales_qty
----------+---------+-------------------------------+-----------
        1 |       1 | 2025-12-24 07:20:20.229051+00 |        10
        2 |       1 | 2025-12-24 07:20:20.229051+00 |         1
        3 |       1 | 2025-12-24 07:20:20.229051+00 |       120
        4 |       2 | 2025-12-24 07:20:20.229051+00 |         1
        5 |       3 | 2025-12-24 07:20:39.142536+00 |         1
        6 |       3 | 2025-12-24 07:20:39.142536+00 |         1
        7 |       3 | 2025-12-24 07:20:39.142536+00 |         2
        8 |       4 | 2025-12-24 07:20:51.44151+00  |         1
        9 |       4 | 2025-12-24 07:20:51.44151+00  |         2
       11 |       4 | 2025-12-24 07:20:51.44151+00  |        20
       12 |       4 | 2025-12-24 07:20:51.44151+00  |       100
       13 |       5 | 2025-12-24 07:20:55.642807+00 |         1
       14 |       5 | 2025-12-24 07:20:55.642807+00 |         3
       15 |       5 | 2025-12-24 07:20:55.642807+00 |         5
       16 |       5 | 2025-12-24 07:20:55.642807+00 |         7
       17 |       5 | 2025-12-24 07:20:55.642807+00 |         9
       18 |       6 | 2025-12-24 07:20:59.673709+00 |         2
       19 |       6 | 2025-12-24 07:20:59.673709+00 |         1
(18 rows)

test_db=# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
order by 1;

select * from good_sum_mart order by 1;
           good_name            |     sum
--------------------------------+--------------
 Fender David Gilmour Signature |     12900.00
 LTD HEX-200 Signature Nergal   |     20000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      2250.00
 Билет консерта Rammstein       |     36900.00
 Спички хозайственные           |        65.50
(6 rows)

           good_name            |   sum_sale
--------------------------------+--------------
 Fender David Gilmour Signature |     12900.00
 LTD HEX-200 Signature Nergal   |     20000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      2250.00
 Билет консерта Rammstein       |     36900.00
 Спички хозайственные           |        65.50
(6 rows)

```

#### UPDATEs

```sql
-- Изменение количевства товаров

test_db=# UPDATE sales set sales_qty = 50 where sales_id = 15 ;
UPDATE 1
test_db=# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
order by 1;

select * from good_sum_mart order by 1;
           good_name            |     sum
--------------------------------+--------------
 Fender David Gilmour Signature |     12900.00
 LTD HEX-200 Signature Nergal   |     20000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      6300.00
 Билет консерта Rammstein       |     36900.00
 Спички хозайственные           |        65.50
(6 rows)

           good_name            |   sum_sale
--------------------------------+--------------
 Fender David Gilmour Signature |     12900.00
 LTD HEX-200 Signature Nergal   |     20000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      6300.00
 Билет консерта Rammstein       |     36900.00
 Спички хозайственные           |        65.50
(6 rows)

-- Изменение ID товара

test_db=# UPDATE sales set good_id = 6 where sales_id = 6 ;
UPDATE 1
test_db=# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
order by 1;

select * from good_sum_mart order by 1;
           good_name            |     sum
--------------------------------+--------------
 Fender David Gilmour Signature |     17200.00
 LTD HEX-200 Signature Nergal   |     15000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      6300.00
 Билет консерта Rammstein       |     36900.00
 Спички хозайственные           |        65.50
(6 rows)

           good_name            |   sum_sale
--------------------------------+--------------
 Fender David Gilmour Signature |     17200.00
 LTD HEX-200 Signature Nergal   |     15000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      6300.00
 Билет консерта Rammstein       |     36900.00
 Спички хозайственные           |        65.50
(6 rows)

-- Изменение количевства и ID товара

test_db=# UPDATE sales set sales_qty = 2, good_id = 4 where sales_id = 14 ;
UPDATE 1
test_db=# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
order by 1;

select * from good_sum_mart order by 1;
           good_name            |     sum
--------------------------------+--------------
 Fender David Gilmour Signature |     17200.00
 LTD HEX-200 Signature Nergal   |     15000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      6030.00
 Билет консерта Rammstein       |     37500.00
 Спички хозайственные           |        65.50
(6 rows)

           good_name            |   sum_sale
--------------------------------+--------------
 Fender David Gilmour Signature |     17200.00
 LTD HEX-200 Signature Nergal   |     15000.00
 Автомобиль Ferrari FXX K       | 185000000.01
 Билет консерта Nagart МСК      |      6030.00
 Билет консерта Rammstein       |     37500.00
 Спички хозайственные           |        65.50
(6 rows)
```

#### TRUNCATEs

```sql
-- Всё, закрылись

test_db=# truncate table sales;
TRUNCATE TABLE
test_db=# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
order by 1;

select * from good_sum_mart order by 1;
 good_name | sum
-----------+-----
(0 rows)

 good_name | sum_sale
-----------+----------
(0 rows)
```


### 6. Вопрос со *

"*Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?*
*Подсказка: В реальной жизни возможны изменения цен."*

Такая схема выгоднее тем, что итог выполняется во время каждой продажи, и итоговая сумма отражает реалные полученны денги, независимо от возможных изменений цен.

```sql
test_db=# INSERT INTO sales (good_id, sales_qty)
VALUES (3, 1), (3, 1), (3, 2);
INSERT 0 3
test_db=# update goods set good_price = 2500 where good_name = 'LTD HEX-200 Signature Nergal';
UPDATE 1
test_db=# SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name
order by 1;

select * from good_sum_mart order by 1;
          good_name           |   sum
------------------------------+----------
 LTD HEX-200 Signature Nergal | 10000.00  << Неверный отчет
(1 row)

          good_name           | sum_sale
------------------------------+----------
 LTD HEX-200 Signature Nergal | 20000.00
(1 row)
```

Однако одним простым способом этого избавить является зафиксирование цены товара во время продажа, в таблице *sales*, где больше не зависят от текущиших цен.
