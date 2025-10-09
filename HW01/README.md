# Демонстрационный пример отчёта в Markdown

## Задание

Приближённо вычислить число $\pi$ с помощью [произведения Валлиса](https://ru.wikipedia.org/wiki/%D0%A4%D0%BE%D1%80%D0%BC%D1%83%D0%BB%D0%B0_%D0%92%D0%B0%D0%BB%D0%BB%D0%B8%D1%81%D0%B0):

$$ \frac{\pi}{2} = \prod_{i=1}^{\infty} \frac{4i^2}{4i^2 - 1}. $$

## Текущая конфигурация

Очередной множитель произведения на Python:

```sh
aduron@ubt-pg-aduron:~$ uname -a
Linux ubt-pg-aduron 6.8.0-85-generic #85-Ubuntu SMP PREEMPT_DYNAMIC Thu Sep 18 15:26:59 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux
```

При разнице последних значений произведения $\pi / 2$ менее `1e-7` вычисленное значение $\pi = 3.1411963131348553$.

![Pi convergence plot](img/convergence_plot.png)

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




## Список использованных источников:

1. [Matplotlib cheatsheets and handouts](https://matplotlib.org/cheatsheets/)
2. [Markdown Cheat Sheet](https://www.markdownguide.org/cheat-sheet/)
3. [Writing mathematical expressions](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/writing-mathematical-expressions)
