# Работа с уровнями изоляции транзакции в PostgreSQL

## Цель

научиться управлять уровнем изоляции транзации в PostgreSQL и понимать особенность работы уровней read commited и repeatable read

## Вывор конфигурации

Для установки и выполнения первого ДЗ, выбираем установку на локальной ВМ через OracleVM Virtualbox.
ВМ имеет следующую конфигурацию

![VM](img/dz1-1.png)

Далее установил Ubuntu 24.04 (серверный) 

```sh
aduron@ubt-pg-aduron:~$ uname -a
Linux ubt-pg-aduron 6.8.0-85-generic #85-Ubuntu SMP PREEMPT_DYNAMIC Thu Sep 18 15:26:59 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
```

При разнице последних значений произведения $\pi / 2$ менее `1e-7` вычисленное значение $\pi = 3.1411963131348553$.



Произведение Валлиса сходится очень медленно, поэтому рекомендуется использовать более эффективные методы вычисления числа $\pi$.

```sh
aduron@ubt-pg-aduron:~$ sudo cat /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: yes
    enp0s8:
      dhcp4: no
      addresses: [192.168.56.10/24]
```


```sh
aduron@ubt-pg-aduron:~$ ip add
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute
       valid_lft forever preferred_lft forever
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:05:2d:38 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic enp0s3
       valid_lft 81909sec preferred_lft 81909sec
    inet6 fe80::a00:27ff:fe05:2d38/64 scope link
       valid_lft forever preferred_lft forever
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:21:d7:98 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.10/24 brd 192.168.56.255 scope global enp0s8
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe21:d798/64 scope link
       valid_lft forever preferred_lft forever
```

### Установка Постгресса 

```sh

```

```sh

```


```sh

```


```sh

```


```sh

```


```sh

```



### Запуск сеансов 


```sh
aduron@ubt-pg-aduron:~$ sudo -u postgres psql
```

```sh
postgres=# \echo AUTOCOMMIT
AUTOCOMMIT
postgres=# \echo :AUTOCOMMIT
OFF
```

AUTOCOMMIT 
When on (the default), each SQL command is automatically committed upon successful completion. To postpone commit in this mode, you must enter a BEGIN or START TRANSACTION SQL command. When off or unset, SQL commands are not committed until you explicitly issue COMMIT or END. The autocommit-off mode works by issuing an implicit BEGIN for you, just before any command that is not already in a transaction block and is not itself a BEGIN or other transaction-control command, nor a command that cannot be executed inside a transaction block (such as VACUUM).


```sh
postgres=# \set PROMPT1 '(%n@SESSION1)>'
(postgres@SESSION1)>
```

```sh
postgres=# \set PROMPT1 '(%n@SESSION2)>'
(postgres@SESSION2)>
```


```sh
(postgres@SESSION1)> create table persons(id serial, first_name text, second_name text);
insert into persons(first_name, second_name) values('ivan', 'ivanov');
insert into persons(first_name, second_name) values('petr', 'petrov');
commit;

CREATE TABLE
INSERT 0 1
INSERT 0 1
COMMIT
(postgres@SESSION1)>
```



## Обзор уровня изоляции транзакции

```sh

```
```sh

```
```sh

```
```sh

```
```sh

```
```sh

```
```sh

```
```sh

```
```sh

```
```sh

```
```sh

```
```sh

```

## Список использованных источников:

1. [Установка постгресса на Ubuntu](https://dev.to/johndotowl/postgresql-17-installation-on-ubuntu-2404-5bfi?ysclid=mgjmgn34tt98683277)
2. [Markdown Cheat Sheet](https://www.markdownguide.org/cheat-sheet/)
3. [Postgres Documentation](https://www.postgresql.org/docs/current/app-psql.html)

