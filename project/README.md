# Проектная работа

## Тема

__Создание и тестирование высоконагруженного отказоустойчивого кластера PostgreSQL на базе Patroni__

## Цель и задачи проекта

Цель проекта: Создать высокодоступный кластер PostgreSQL, развёртывание и обслуживание которого будут автоматизированы модулями Patroni и etcd, и тестировать отказоустойчивость кластера в рамках планированного и непланированного переключения роли.

- [x] Создание виртуальной кластеризованной среды Ubuntu c распределённом хранилищем конфигурации etcd
- [x] Настраивание модули управления Patroni
- [x] Тестирование переключения и отказоустойчивости кластера
- [x] Тестирование отказоустойчивость и переключение клиентов с помощью HAProxy

> [!NOTE]
> Здесь показано галочками какие задачи были выполнены


## Архитектура

### Используеммые технологии

Для выполнения этого проекта исползовались следующие текнологии 

| Роль                                        | Название                | Версия                     | Коментарии               |
| ------------------------------------------- | ----------------------- | -------------------------- | ------------------------ |
| Слой виртуализации                          | Oracle VM Virtualbox    | 7.0.22 r165102 (Qt5.15.2)  |                          |
| ОЦ кластера                                 | Ubuntu                  | 24.04.3 LTS (серверный)    |                          |
| DCS (распределённое хранилище конфигурации) | etcd                    | 3.4.30                     | repository (precompiled) |
| Слой отказоустойчивости Postgres            | Patroni                 |                            |                          |
| База данных                                 | Postgres                | 18                         | repository (precompiled) |

### Сетевая топологиа

Подсети виртуальной среды былти настроены вот таким образом для выполнения этого проекта:

| Network name                     | Подсеть          | Маск          | Исползование           |
| -------------------------------- | ---------------- | ------------- | ---------------------- |
| VirtualBox Host-Only Adapter     | 192.168.56.1/24  | 255.255.255.0 | postgres кластер IPs   |
| VirtualBox Host-Only Adapter #2  | 192.168.47.1/24  | 255.255.255.0 | etcd кластер IPs       |

Виртуальные машины кластера имеют сдедующа сетевая топология:

| Название хоста          | Название DCS         | Общий IP      | Айпи етсд     | Исползование                    |
| ----------------------- | -------------------- | ------------- | ------------- | ------------------------------- | 
| ubt-pg-aduron-dbnode1   | ubt-pg-aduron-etcd1  | 192.168.56.10 | 192.168.47.10 | Мастер кластера Postgres        |
| ubt-pg-aduron-dbnode2   | ubt-pg-aduron-etcd2  | 192.168.56.20 | 192.168.47.20 | Реплиса кластера Postgres       |
| ubt-pg-aduron-cluster3  | ubt-pg-aduron-etcd3  | 192.168.56.30 | 192.168.47.30 | Допольнительный DCS-хост        |

> [!NOTE]
> Также отмечаем, что каждая машина имеет допольнительный сетеввой доступ типа NAT, который используется для их полключения к интернету.


### Диаграм архитектуры

</br><img src="img/diagram.png" width="800" />

## Выполнение проекта


### Создание виртуалной кластеризованной среды Ubuntu c распределённом хранилищем конфигурации etcd


#### Создание сетевой конфигурации

По умолчанию, Oracle VM VirtualBox предоставляет одну подсеть типа *Virtual Host Adapter* (виртуальный адаптер хоста), которая полволяет подключаться к ВМ с хоста. Однако для создания более [реалистичной архитектуры](#сетевая-топологиа), нам понадобится и одна допольнительная подсеть для управления кластером etcd. Создать её в VirtualBox можно следующим образом:

Выбрать меню *Файл / Инструменты / Менеджер Сетей*, затем нажать кнопку *Создать*
</br><img src="img/1_vm_install/net-1.png" width="1000" />  

Заполнить детали новой подсети таким способом:
</br><img src="img/1_vm_install/net-2.png" width="1000" />


#### Установление первой виртуалной машины

> [!NOTE]
> Предварительно [cкачать Ubuntu Server 24.04 LTS](https://ubuntu.com/download/server)

В данном случае, установим первую виртуалную машину, со всеми нужными компнентами и утилитами, а дальше сможем её клонировать для интеграция допольнительных хостов, что ускорит процесс установления всего кластера. Для создания новой виртуальной машины, выбираем кнокпу *Создать* и дальше выполняем следующие шаги:
- В разделе *Имя и тип ОЦ* выбираем имя, образ ISO, папку, тип и версию Линукса. 
- В разделе *Автоматическая установка* добавляем детали пользователя и хоста
- В разделе *Обарудование* выбираем выделенные ресурсы нашей ВМ.
- В разделе *Жёсткий диск* заполняем детали виртуального диска (расположение, размер, тип VDI, без выделения места в полном размере)

<details>
<summary>Шаг 1: Выбор виртуальной конфигурации</summary>
</br><img src="img/1_vm_install/create-1.png" width="800" />
</br><img src="img/1_vm_install/create-2.png" width="800" />
</br><img src="img/1_vm_install/create-3.png" width="800" />
</br><img src="img/1_vm_install/create-4.png" width="800" />
</details>

> [!WARNING]
> При этом, автоматическая установка не всегда запускается как запрошено, и её доступность зависит по всей видимости от вывранного образа ISO. В данном случае приходится всё же заполнить все детали занова при установке.

Дальше, выбираем кнопку *Готого*, что создавает виртуалный диск, выделяет ресурсы, и запускает процесс установки. Однако сразу же остановим машину после запуска, и переидём в разделе *Сеть* (на главном екране, либо через менью *Машина / Настроить*). Здесь включаем адаптеры 1, 2 и 3 согласно [выбраной сетевой конфигурации](#сетевая-топологиа). 

<details>
<summary>Шаг 2: Выбор сетевой конфигурации ВМ</summary>
</br><img src="img/1_vm_install/create-5.png" width="800" />
</br><img src="img/1_vm_install/create-6.png" width="800" />
</br><img src="img/1_vm_install/create-7.png" width="800" />
</details>


После выполнения сетевой конфигурации, можно снова закускать ВМ и начинать процесс установления. Он происходит следующим образом:
1. Определение языка и настроек клавятуры.
2. Выбор метода установки (выбираем *Ubuntu Server* )
3. Дальше настраиваем сеть таким образом:
   - для интерфейса *enp0s8* отключаем DHCP и выбираем значение *Manual* для *IPv4 Method*
   - поставляем айпи 192.168.56.10 для *enp0s8*
   - поставляем айпи 192.168.47.10 для *enp0s9* (подсеть etcd). Для этого интерфейса не требуеться отключения DHCP так как он отключен изначално
   - Проху оставляем как есть, а также оставляем зеркало установления по умолчанию
4. Настройки хранилища и партиционирования, профиль пользователя:
   - *Use an entire disk* (использовать весь диска)
   - *Set up LVM*
   - В разделе *profile configuration*, заполняем данные главного пользователя 
   - Ставим OpenSSH (требуется попозже во время внешнего подключения)
5. Дальше можно добавить различные репозитории сторонных ПО.
   - В данном случае можно добавить *etcd*, 
   - Также можно сразк же указать, к какой версии мы хотим получить доступ. Здесь выбираем самую свежую стабтльную версию (среди предоставленных).

<details>
<summary>Шаг 3.1: Определение языка и настроек клавятуры</summary>
</br><img src="img/1_vm_install/install-1.png" width="800" />
</br><img src="img/1_vm_install/install-2.png" width="1000" />
</br><img src="img/1_vm_install/install-3.png" width="1000" />
</details>

<details>
<summary>Шаг 3.2: Выбор метода установки</summary>
</br><img src="img/1_vm_install/install-4.png" width="1000" />
</details>

<details>
<summary>Шаг 3.3: Сетевые настроики, прокси, зеркало</summary>
</br><img src="img/1_vm_install/install-5.png" width="1000" />
</br><img src="img/1_vm_install/install-6.png" width="1000" />
</br><img src="img/1_vm_install/install-7.png" width="1000" />
</br><img src="img/1_vm_install/install-8.png" width="1000" />
</br><img src="img/1_vm_install/install-9.png" width="1000" />

</br><img src="img/1_vm_install/install-10.png" width="1000" />
</br><img src="img/1_vm_install/install-11.png" width="1000" />
</details>

<details>
<summary>Шаг 3.4: Настройки хранилища и партиционирования, профиль пользователя</summary>
</br><img src="img/1_vm_install/install-12.png" width="1000" />
</br><img src="img/1_vm_install/install-13.png" width="1000" />
</br><img src="img/1_vm_install/install-14.png" width="1000" />
</br><img src="img/1_vm_install/install-15.png" width="1000" />
</br><img src="img/1_vm_install/install-16.png" width="1000" />
</details>

<details>
<summary>Шаг 3.5: Featured server snaps (сторонные ПО)</summary>
</br><img src="img/1_vm_install/install-19.png" width="1000" />
</br><img src="img/1_vm_install/install-18.png" width="1000" />
</details>

> [!CAUTION]
> Обращаем внимание на то, что самая высокая версия, доступна таким способом не является самой свежой. В момент создание этого проекта, самая свежый релиз *etcd* - 3.6.7 <sup id="a1">[(1)](#f1)</sup>. Поэтому, если хотите установить именно какую-то более свежую версию, лучше этого сделать путем клонирования *github* или установляя уже подготовленных двойчных с сайта *etcd*.

После заполнения всех деталей и проверки, выпольняется установка.
</br><img src="img/1_vm_install/install-20.png" width="1000" />


#### Конфигурация ssh-подключения 

> [!NOTE]
> Если не ставили OpenSSH во врумя установки, предварительно придётся запустить `apt install openssh` чтобы установить пакет. Более того, не будет демонстрировать здесь самого процесса создания ключа. Сделать это можно с помощью Pytty-Keygen на виндос или ssh-keygen на линуксе.

Создадим папку обмена, в которой находится наш публичный ssh ключ.

на главном екране нащей машины, нажать *общие папки* и добадить детали папки и монтирования
- Путь на хосте
- Имя: RSA
- Точка подключения: /mnt/rsa

<details>
<summary>Добавление общей папки обмена между хостом виртуализации и ВМ</summary>
</br><img src="img/1_vm_install/key-0.png" width="1000" />
</br><img src="img/1_vm_install/key-1.png" width="1000" />
</br><img src="img/1_vm_install/key-2.png" width="1000" />
</details>

> [!TIP]
> Папку лучше создать временную. Таким образом она исчезнет после следующего перезапуска машины. 

Дальше, на ВМ создаваем точка подключения и запускаем команду `mount`

```sh
sudo mkdir /mnt/rsa
sudo chmod 777 /mnt/rsa
sudo mount -t vboxsf RSA /mnt/rsa
```

И добавляем ключ среди авторизаванныз для подключения к этой машине
```sh
cat /mnt/rsa/public_aduron.pub >> ~/.ssh/authorized_keys
```

Проверим, что можем успешно подключиться к ВМ с помощью нащего ключа

```sh
Using username "aduron".
Authenticating with public key "rsa-key-20241127"
Welcome to Ubuntu 24.04.3 LTS (GNU/Linux 6.8.0-90-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Fri Jan  2 02:12:38 PM UTC 2026

  System load:  0.01               Processes:               113
  Usage of /:   40.4% of 11.21GB   Users logged in:         1
  Memory usage: 9%                 IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

59 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status


/usr/bin/xauth:  file /home/aduron/.Xauthority does not exist
aduron@ubt-pg-aduron-dbnode1:~$
```

После этого, точку можно удалить так как она больше н понадобится.

```sh
sudo umount RSA
```


#### Проверка сетевых настроек

Проверим сетевую конфигурацию с помощью утилита `netplan`.
Она должна выглядить следующим образом:

```sh
aduron@ubt-pg-aduron-dbnode1:~$ netplan status
     Online state: online
    DNS Addresses: 127.0.0.53 (stub)
       DNS Search: Home

●  1: lo ethernet UNKNOWN/UP (unmanaged)
      MAC Address: 00:00:00:00:00:00
        Addresses: 127.0.0.1/8
                   ::1/128

●  2: enp0s3 ethernet UP (networkd: enp0s3)
      MAC Address: 08:00:27:38:ee:12 (Intel Corporation)
        Addresses: 10.0.2.15/24 (dynamic, dhcp)
                   fe80::a00:27ff:fe38:ee12/64 (link)
    DNS Addresses: 192.168.0.1
       DNS Search: Home
           Routes: default via 10.0.2.2 from 10.0.2.15 metric 100 (dhcp)
                   10.0.2.0/24 from 10.0.2.15 metric 100 (link)
                   10.0.2.2 from 10.0.2.15 metric 100 (dhcp, link)
                   192.168.0.1 via 10.0.2.2 from 10.0.2.15 metric 100 (dhcp)
                   fe80::/64 metric 256

●  3: enp0s8 ethernet UP (networkd: enp0s8)
      MAC Address: 08:00:27:84:a9:9b (Intel Corporation)
        Addresses: 192.168.56.10/24
                   fe80::a00:27ff:fe84:a99b/64 (link)
           Routes: 192.168.56.0/24 from 192.168.56.10 (link)
                   fe80::/64 metric 256

●  4: enp0s9 ethernet UP (networkd: enp0s9)
      MAC Address: 08:00:27:34:b1:2d (Intel Corporation)
        Addresses: 192.168.47.10/24
                   fe80::a00:27ff:fe34:b12d/64 (link)
           Routes: 192.168.47.0/24 from 192.168.47.10 (link)
                   fe80::/64 metric 256
```

Далее проверяем файл настроек. Он должен выглядить вот так

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo cat /etc/netplan/50-cloud-init.yaml
[sudo] password for aduron:
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses:
      - "192.168.56.10/24"
      routes:
      - to: "default"
        via: "255.255.255.0"
    enp0s9:
      addresses:
      - "192.168.47.10/24"
```

> [!TIP]
> Если для *enp0s9* также существует маршрут по умолчанию, лучше его удалить и оставить только для *enp0s8*, а то могут случиться конфликты.

Далее, переходим к файлу настроек сервиса *systemd-networkd-wait-online.service* и добавляем значение *TimeoutSec=10* в секции *Service*. Это значительно ускоряет процесс перезапуска ВМ так так эта служба больще не бужет ждать до 120 сек для проверки доступности сети. Что безполезно в любом случае так как сетевые настроики сделаны вручную с отсутствием пакета *NetworkManager*.

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo cat /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
#  SPDX-License-Identifier: LGPL-2.1-or-later
#
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.

[Unit]
Description=Wait for Network to be Configured
Documentation=man:systemd-networkd-wait-online.service(8)
ConditionCapability=CAP_NET_ADMIN
DefaultDependencies=no
Conflicts=shutdown.target
BindsTo=systemd-networkd.service
After=systemd-networkd.service
Before=network-online.target shutdown.target

[Service]
Type=oneshot
ExecStart=/usr/lib/systemd/systemd-networkd-wait-online
RemainAfterExit=yes
TimeoutSec=10

[Install]
WantedBy=network-online.target
```

Зафиксируем измениении:

```sh
sudo systemctl reload-daemon
sudo systemctl enable systemd-networkd-wait-online.service
```

И конечно, в файле `/etc/hosts` добавим айпи и имя хоста всех машин в кластере. 

```sh
aduron@ubt-pg-aduron-dbnode1:~$ cat /etc/hosts
127.0.0.1 localhost
#127.0.1.1 ubt-pg-aduron-dbnode1
192.168.56.10 ubt-pg-aduron-dbnode1
192.168.47.10 ubt-pg-aduron-etcd1
192.168.56.20 ubt-pg-aduron-dbnode2
192.168.47.20 ubt-pg-aduron-etcd2
192.168.56.30 ubt-pg-aduron-cluster3
192.168.47.30 ubt-pg-aduron-etcd3

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

#### Обновление системных пакетов и добавление репозитории Постгреса

Во первых устанавливаем системные обновления:

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo apt update && sudo apt upgrade
Get:1 http://security.ubuntu.com/ubuntu noble-security InRelease [126 kB]
Hit:2 http://archive.ubuntu.com/ubuntu noble InRelease
Hit:3 http://archive.ubuntu.com/ubuntu noble-updates InRelease
Get:4 http://security.ubuntu.com/ubuntu noble-security/main amd64 Components [21.5 kB]
Hit:5 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Get:6 http://security.ubuntu.com/ubuntu noble-security/restricted amd64 Components [212 B]
Get:7 http://security.ubuntu.com/ubuntu noble-security/universe amd64 Components [71.5 kB]
Get:8 http://security.ubuntu.com/ubuntu noble-security/multiverse amd64 Components [212 B]
Fetched 220 kB in 1s (322 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
59 packages can be upgraded. Run 'apt list --upgradable' to see them.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Calculating upgrade... Done
The following packages will be upgraded:
  apparmor bsdextrautils bsdutils cloud-init coreutils dhcpcd-base distro-info-data eject fdisk fwupd gir1.2-glib-2.0 gir1.2-packagekitglib-1.0 landscape-common libapparmor1 libblkid1 libdrm-common
  libdrm2 libfdisk1 libfwupd2 libglib2.0-0t64 libglib2.0-bin libglib2.0-data libmbim-glib4 libmbim-proxy libmbim-utils libmount1 libnetplan1 libnss-systemd libpackagekit-glib2-18 libpam-systemd
  libsmartcols1 libsystemd-shared libsystemd0 libudev1 libuuid1 mount netplan-generator netplan.io packagekit packagekit-tools powermgmt-base python3-netplan python3-software-properties snapd
  software-properties-common sosreport systemd systemd-dev systemd-hwe-hwdb systemd-resolved systemd-sysv systemd-timesyncd tcpdump ubuntu-drivers-common ubuntu-pro-client ubuntu-pro-client-l10n udev
  util-linux uuid-runtime
59 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
Need to get 57.2 MB of archives.
After this operation, 3,950 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 bsdutils amd64 1:2.39.3-9ubuntu6.4 [95.6 kB]
Get:2 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 coreutils amd64 9.4-3ubuntu6.1 [1,413 kB]
Get:3 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 util-linux amd64 2.39.3-9ubuntu6.4 [1,128 kB]
Get:4 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 mount amd64 2.39.3-9ubuntu6.4 [118 kB]
Get:5 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 libnss-systemd amd64 255.4-1ubuntu8.12 [159 kB]
Get:6 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 systemd-dev all 255.4-1ubuntu8.12 [106 kB]
Get:7 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 libblkid1 amd64 2.39.3-9ubuntu6.4 [123 kB]
...
Get:58 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 sosreport amd64 4.9.2-0ubuntu0~24.04.1 [372 kB]
Get:59 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 cloud-init all 25.2-0ubuntu1~24.04.1 [625 kB]
Fetched 57.2 MB in 9s (6,278 kB/s)
Extracting templates from packages: 100%
Preconfiguring packages ...
(Reading database ... 87356 files and directories currently installed.)
Preparing to unpack .../bsdutils_1%3a2.39.3-9ubuntu6.4_amd64.deb ...
Unpacking bsdutils (1:2.39.3-9ubuntu6.4) over (1:2.39.3-9ubuntu6.3) ...
Setting up bsdutils (1:2.39.3-9ubuntu6.4) ...
...
Processing triggers for install-info (7.1-3build2) ...
Processing triggers for initramfs-tools (0.142ubuntu25.5) ...
update-initramfs: Generating /boot/initrd.img-6.8.0-90-generic
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...
 systemctl restart multipathd.service polkit.service ssh.service udisks2.service upower.service

Service restarts being deferred:
 systemctl restart ModemManager.service
 /etc/needrestart/restart.d/dbus.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service

No containers need to be restarted.

User sessions running outdated binaries:
 aduron @ session #1: login[864]
 aduron @ session #3: apt[1481], sshd[1092]
 aduron @ user manager service: systemd[968]

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

Добавляем репозитори постгреса:

> [!WARNING]
> Комманда *curl* может завершиться с ошибками устарения сертификата (`curl: (60) SSL certificate problem: self-signed certificate in certificate chain`), если сертификаты не были обновлены после установки ВМ. Поэтому лучше их предварительно обновлять следующим образом:

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo apt upgrade ca-certificates
```

Добавляем репозитори постгреса:

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
aduron@ubt-pg-aduron-dbnode1:~$ curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
aduron@ubt-pg-aduron-dbnode1:~$ sudo apt update
Hit:1 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:2 http://archive.ubuntu.com/ubuntu noble InRelease
Get:3 http://apt.postgresql.org/pub/repos/apt noble-pgdg InRelease [107 kB]
Get:4 http://archive.ubuntu.com/ubuntu noble-updates InRelease [126 kB]
Get:5 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 Packages [353 kB]
Get:6 http://archive.ubuntu.com/ubuntu noble-backports InRelease [126 kB]
Get:7 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 Components [175 kB]
Get:8 http://archive.ubuntu.com/ubuntu noble-updates/restricted amd64 Components [208 B]
Get:9 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 Components [378 kB]
Get:10 http://archive.ubuntu.com/ubuntu noble-updates/multiverse amd64 Components [940 B]
Get:11 http://archive.ubuntu.com/ubuntu noble-backports/main amd64 Components [7,284 B]
Get:12 http://archive.ubuntu.com/ubuntu noble-backports/restricted amd64 Components [212 B]
Get:13 http://archive.ubuntu.com/ubuntu noble-backports/universe amd64 Components [10.5 kB]
Get:14 http://archive.ubuntu.com/ubuntu noble-backports/multiverse amd64 Components [212 B]
Fetched 1,284 kB in 2s (733 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
All packages are up to date.
```

Далее устанавливаем *Postgres-18*
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo apt install postgresql-18
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libcommon-sense-perl libjson-perl libjson-xs-perl libllvm19 libpq5 libtypes-serialiser-perl liburing2 postgresql-18-jit postgresql-client-18 postgresql-client-common postgresql-common ssl-cert
Suggested packages:
  libpq-oauth postgresql-doc-18
The following NEW packages will be installed:
  libcommon-sense-perl libjson-perl libjson-xs-perl libllvm19 libpq5 libtypes-serialiser-perl liburing2 postgresql-18 postgresql-18-jit postgresql-client-18 postgresql-client-common postgresql-common
  ssl-cert
0 upgraded, 13 newly installed, 0 to remove and 0 not upgraded.
Need to get 48.9 MB of archives.
After this operation, 203 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://archive.ubuntu.com/ubuntu noble/main amd64 libjson-perl all 4.10000-1 [81.9 kB]
Get:2 http://archive.ubuntu.com/ubuntu noble/main amd64 ssl-cert all 1.1.2ubuntu1 [17.8 kB]
Get:3 http://archive.ubuntu.com/ubuntu noble/main amd64 libcommon-sense-perl amd64 3.75-3build3 [20.4 kB]
Get:4 http://archive.ubuntu.com/ubuntu noble/main amd64 libtypes-serialiser-perl all 1.01-1 [11.6 kB]
Get:5 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 libjson-xs-perl amd64 4.040-0ubuntu0.24.04.1 [83.7 kB]
Get:6 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 libllvm19 amd64 1:19.1.1-1ubuntu1~24.04.2 [28.7 MB]
Get:7 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-client-common all 287.pgdg24.04+1 [47.9 kB]
Get:8 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-common all 287.pgdg24.04+1 [112 kB]
Get:9 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 libpq5 amd64 18.1-1.pgdg24.04+2 [245 kB]
Get:10 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-client-18 amd64 18.1-1.pgdg24.04+2 [2,086 kB]
Get:11 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-18 amd64 18.1-1.pgdg24.04+2 [7,516 kB]
Get:12 http://archive.ubuntu.com/ubuntu noble/main amd64 liburing2 amd64 2.5-1build1 [21.1 kB]
Get:13 http://apt.postgresql.org/pub/repos/apt noble-pgdg/main amd64 postgresql-18-jit amd64 18.1-1.pgdg24.04+2 [9,871 kB]
Fetched 48.9 MB in 3s (16.0 MB/s)
Preconfiguring packages ...
Selecting previously unselected package libjson-perl.
(Reading database ... 87378 files and directories currently installed.)
Preparing to unpack .../00-libjson-perl_4.10000-1_all.deb ...
Unpacking libjson-perl (4.10000-1) ...
Selecting previously unselected package postgresql-client-common.
Preparing to unpack .../01-postgresql-client-common_287.pgdg24.04+1_all.deb ...
Unpacking postgresql-client-common (287.pgdg24.04+1) ...
Selecting previously unselected package ssl-cert.
Preparing to unpack .../02-ssl-cert_1.1.2ubuntu1_all.deb ...
Unpacking ssl-cert (1.1.2ubuntu1) ...
Selecting previously unselected package postgresql-common.
Preparing to unpack .../03-postgresql-common_287.pgdg24.04+1_all.deb ...
Adding 'diversion of /usr/bin/pg_config to /usr/bin/pg_config.libpq-dev by postgresql-common'
Unpacking postgresql-common (287.pgdg24.04+1) ...
Selecting previously unselected package libcommon-sense-perl:amd64.
Preparing to unpack .../04-libcommon-sense-perl_3.75-3build3_amd64.deb ...
Unpacking libcommon-sense-perl:amd64 (3.75-3build3) ...
Selecting previously unselected package libtypes-serialiser-perl.
Preparing to unpack .../05-libtypes-serialiser-perl_1.01-1_all.deb ...
Unpacking libtypes-serialiser-perl (1.01-1) ...
Selecting previously unselected package libjson-xs-perl.
Preparing to unpack .../06-libjson-xs-perl_4.040-0ubuntu0.24.04.1_amd64.deb ...
Unpacking libjson-xs-perl (4.040-0ubuntu0.24.04.1) ...
Selecting previously unselected package libllvm19:amd64.
Preparing to unpack .../07-libllvm19_1%3a19.1.1-1ubuntu1~24.04.2_amd64.deb ...
Unpacking libllvm19:amd64 (1:19.1.1-1ubuntu1~24.04.2) ...
Selecting previously unselected package libpq5:amd64.
Preparing to unpack .../08-libpq5_18.1-1.pgdg24.04+2_amd64.deb ...
Unpacking libpq5:amd64 (18.1-1.pgdg24.04+2) ...
Selecting previously unselected package liburing2:amd64.
Preparing to unpack .../09-liburing2_2.5-1build1_amd64.deb ...
Unpacking liburing2:amd64 (2.5-1build1) ...
Selecting previously unselected package postgresql-client-18.
Preparing to unpack .../10-postgresql-client-18_18.1-1.pgdg24.04+2_amd64.deb ...
Unpacking postgresql-client-18 (18.1-1.pgdg24.04+2) ...
Selecting previously unselected package postgresql-18.
Preparing to unpack .../11-postgresql-18_18.1-1.pgdg24.04+2_amd64.deb ...
Unpacking postgresql-18 (18.1-1.pgdg24.04+2) ...
Selecting previously unselected package postgresql-18-jit.
Preparing to unpack .../12-postgresql-18-jit_18.1-1.pgdg24.04+2_amd64.deb ...
Unpacking postgresql-18-jit (18.1-1.pgdg24.04+2) ...
Setting up postgresql-client-common (287.pgdg24.04+1) ...
Setting up libllvm19:amd64 (1:19.1.1-1ubuntu1~24.04.2) ...
Setting up libpq5:amd64 (18.1-1.pgdg24.04+2) ...
Setting up libcommon-sense-perl:amd64 (3.75-3build3) ...
Setting up ssl-cert (1.1.2ubuntu1) ...
Created symlink /etc/systemd/system/multi-user.target.wants/ssl-cert.service → /usr/lib/systemd/system/ssl-cert.service.
Setting up libtypes-serialiser-perl (1.01-1) ...
Setting up libjson-perl (4.10000-1) ...
Setting up liburing2:amd64 (2.5-1build1) ...
Setting up libjson-xs-perl (4.040-0ubuntu0.24.04.1) ...
Setting up postgresql-client-18 (18.1-1.pgdg24.04+2) ...
update-alternatives: using /usr/share/postgresql/18/man/man1/psql.1.gz to provide /usr/share/man/man1/psql.1.gz (psql.1.gz) in auto mode
Setting up postgresql-common (287.pgdg24.04+1) ...

Creating config file /etc/postgresql-common/createcluster.conf with new version
Building PostgreSQL dictionaries from installed myspell/hunspell packages...
Removing obsolete dictionary files:
Created symlink /etc/systemd/system/multi-user.target.wants/postgresql.service → /usr/lib/systemd/system/postgresql.service.
Setting up postgresql-18 (18.1-1.pgdg24.04+2) ...
Creating new PostgreSQL cluster 18/main ...
/usr/lib/postgresql/18/bin/initdb -D /var/lib/postgresql/18/main --auth-local peer --auth-host scram-sha-256 --no-instructions
The files belonging to this database system will be owned by user "postgres".
This user must also own the server process.

The database cluster will be initialized with locale "en_US.UTF-8".
The default database encoding has accordingly been set to "UTF8".
The default text search configuration will be set to "english".

Data page checksums are enabled.

fixing permissions on existing directory /var/lib/postgresql/18/main ... ok
creating subdirectories ... ok
selecting dynamic shared memory implementation ... posix
selecting default "max_connections" ... 100
selecting default "shared_buffers" ... 128MB
selecting default time zone ... Etc/UTC
creating configuration files ... ok
running bootstrap script ... ok
performing post-bootstrap initialization ... ok
syncing data to disk ... ok
Setting up postgresql-18-jit (18.1-1.pgdg24.04+2) ...
Processing triggers for libc-bin (2.39-0ubuntu8.6) ...
Processing triggers for man-db (2.12.0-4build2) ...
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...

Service restarts being deferred:
 /etc/needrestart/restart.d/dbus.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service

No containers need to be restarted.

User sessions running outdated binaries:
 aduron @ session #1: login[864]
 aduron @ session #3: sshd[1092]
 aduron @ user manager service: systemd[968]

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

Установка создаст кластер 18-main по умолчанию с запущеной службой в *systemd*, что не выгодно в нашем случае так час кластер будет запускаться и управляться модулем *Patroni*. поэтому мы его отключаем:

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl --now disable postgresql@18-main.service
aduron@ubt-pg-aduron-dbnode1:~$ systemctl status postgresql@18-main.service
○ postgresql@18-main.service - PostgreSQL Cluster 18-main
     Loaded: loaded (/usr/lib/systemd/system/postgresql@.service; enabled-runtime; preset: enabled)
     Active: inactive (dead) since Fri 2026-01-02 14:43:54 UTC; 37s ago
   Duration: 5min 8.830s
   Main PID: 12183 (code=exited, status=0/SUCCESS)
        CPU: 470ms

Jan 02 14:38:43 ubt-pg-aduron-dbnode1 systemd[1]: Starting postgresql@18-main.service - PostgreSQL Cluster 18-main...
Jan 02 14:38:45 ubt-pg-aduron-dbnode1 systemd[1]: Started postgresql@18-main.service - PostgreSQL Cluster 18-main.
Jan 02 14:43:54 ubt-pg-aduron-dbnode1 systemd[1]: Stopping postgresql@18-main.service - PostgreSQL Cluster 18-main...
Jan 02 14:43:54 ubt-pg-aduron-dbnode1 systemd[1]: postgresql@18-main.service: Deactivated successfully.
Jan 02 14:43:54 ubt-pg-aduron-dbnode1 systemd[1]: Stopped postgresql@18-main.service - PostgreSQL Cluster 18-main.

aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl disable postgresql.service
```

#### Установка etcd

Здесь выбираем установки через `apt install` и влкюченного репозитория. Дальше будет обяснено, почему таким путем не идеален, и что можно делать чтобы это корректировать. 

Сначала установим пакет `etcd-server`  

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo apt install etcd-server
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Suggested packages:
  etcd-client
The following NEW packages will be installed:
  etcd-server
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 9,184 kB of archives.
After this operation, 25.3 MB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 etcd-server amd64 3.4.30-1ubuntu0.24.04.3 [9,184 kB]
Fetched 9,184 kB in 1s (12.5 MB/s)
Selecting previously unselected package etcd-server.
(Reading database ... 89759 files and directories currently installed.)
Preparing to unpack .../etcd-server_3.4.30-1ubuntu0.24.04.3_amd64.deb ...
Unpacking etcd-server (3.4.30-1ubuntu0.24.04.3) ...
Setting up etcd-server (3.4.30-1ubuntu0.24.04.3) ...
Could not execute systemctl:  at /usr/bin/deb-systemd-invoke line 148.
Processing triggers for man-db (2.12.0-4build2) ...
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...

Service restarts being deferred:
 /etc/needrestart/restart.d/dbus.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service

No containers need to be restarted.

User sessions running outdated binaries:
 aduron @ session #1: login[864]
 aduron @ session #3: sshd[1092]
 aduron @ user manager service: systemd[968]

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

Однако здесь отмечается, что systemd не смог создать службу:

```sh
Could not execute systemctl:  at /usr/bin/deb-systemd-invoke line 148.
```

команда `journalctl` показывает что не существует необходимый ETCD_DATA_DIR
```sh
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: recognized and used environment variable ETCD_DATA_DIR=/var/lib/etcd/default
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: recognized and used environment variable ETCD_NAME=ubt-pg-aduron-dbnode1
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: [WARNING] Deprecated '--logger=capnslog' flag is set; use '--logger=zap' flag instead
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: Running http and grpc server on single port. This is not recommended for production.
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: etcd Version: 3.4.30
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: Git SHA: Not provided (use ./build instead of go build)
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: Go Version: go1.22.2
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: Go OS/Arch: linux/amd64
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: setting maximum number of CPUs to 2, total number of available CPUs is 2
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 etcd[13666]: error listing data dir: /var/lib/etcd/default
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 systemd[1]: etcd.service: Main process exited, code=exited, status=1/FAILURE
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 systemd[1]: etcd.service: Failed with result 'exit-code'.
Jan 02 15:21:53 ubt-pg-aduron-dbnode1 systemd[1]: Failed to start etcd.service - etcd - highly-available key value store.
```

Создадим эту папку...
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo mkdir -p /var/lib/etcd/default 
aduron@ubt-pg-aduron-dbnode1:~$ sudo chown -R etcd:etcd /var/lib/etcd
aduron@ubt-pg-aduron-dbnode1:~$ sudo chmod -R 755 /var/lib/etcd/
```

... что в итоге позволяет завершить установки

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo apt install etcd-server
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Suggested packages:
  etcd-client
The following NEW packages will be installed:
  etcd-server
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 9,184 kB of archives.
After this operation, 25.3 MB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 etcd-server amd64 3.4.30-1ubuntu0.24.04.3 [9,184 kB]
Fetched 9,184 kB in 1s (11.9 MB/s)
Selecting previously unselected package etcd-server.
(Reading database ... 89759 files and directories currently installed.)
Preparing to unpack .../etcd-server_3.4.30-1ubuntu0.24.04.3_amd64.deb ...
Unpacking etcd-server (3.4.30-1ubuntu0.24.04.3) ...
Setting up etcd-server (3.4.30-1ubuntu0.24.04.3) ...
Processing triggers for man-db (2.12.0-4build2) ...
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...

Service restarts being deferred:
 /etc/needrestart/restart.d/dbus.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service

No containers need to be restarted.

User sessions running outdated binaries:
 aduron @ session #1: login[864]
 aduron @ session #3: sshd[1092]
 aduron @ user manager service: systemd[968]

No VM guests are running outdated hypervisor (qemu) binaries on this host.


aduron@ubt-pg-aduron-dbnode1:~$ etcd -version
etcd Version: 3.4.30
Git SHA: Not provided (use ./build instead of go build)
Go Version: go1.22.2
Go OS/Arch: linux/amd64
```

Служба *etcd* в systemd автоматично создана при установке, что является единственным прибылом выбранного метода:  
```sh
aduron@ubt-pg-aduron-dbnode1:~$ systemctl status etcd
● etcd.service - etcd - highly-available key value store
     Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-01-02 15:48:44 UTC; 1min 47s ago
       Docs: https://etcd.io/docs
             man:etcd
   Main PID: 15988 (etcd)
      Tasks: 8 (limit: 2267)
     Memory: 5.3M (peak: 5.6M)
        CPU: 1.198s
     CGroup: /system.slice/etcd.service
             └─15988 /usr/bin/etcd

Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: raft2026/01/02 15:48:44 INFO: 8e9e05c52164694d received MsgVoteResp from 8e9e05c52164694d at term 2
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: raft2026/01/02 15:48:44 INFO: 8e9e05c52164694d became leader at term 2
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: raft2026/01/02 15:48:44 INFO: raft.node: 8e9e05c52164694d elected leader 8e9e05c52164694d at term 2
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: published {Name:ubt-pg-aduron-dbnode1 ClientURLs:[http://localhost:2379]} to cluster cdf818194e3a8c32
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: setting up the initial cluster version to 3.4
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: ready to serve client requests
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 systemd[1]: Started etcd.service - etcd - highly-available key value store.
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: set the initial cluster version to 3.4
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: enabled capabilities for version 3.4
```

> [!CAUTION]
> Сдеди недостатки такого метода поставки, стоит умомянуть следующие пункты:
> - Недоступность свежих версий (репозитори задержается примерно на 4 месяца и не включает последние релизы, что даже отмечено на сайте продукта) 
> - Очень неожиданное поведение интеграции службы *systemd*, если до этого были сделаны попытки установки другим способом
> - Непонятное отсутствие клиентских компонентов, которые в предыдушых версиях Ubuntu были включены. Теперь преходится установить отдельно серверную и клиентскую части.
> - Сложность при апгрейде (об этом дальще) 


#### Создание сертификатов etcd

Во время запуска службы отмечается вот такое сообщение 
```sh
Jan 02 15:48:44 ubt-pg-aduron-dbnode1 etcd[15988]: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
```

В продовом контексте лучше не запускать etcd таким образом без каких либо сертификатов ssl. Шаги создания:
1. Создание rsa-ключ CA (`openssl genrsa -out ca.key 4096`)
2. Создание CA-сертификата (`openssl req -x509 -new -key ca.key -days 10000 -out ca.crt -subj "/C=RU/ST=Region/L=City/O=MyOrg/OU=MyUnit/CN=myorg.com"`)
3. Для каждого хоста etcd создать
   - rsa-ключ для аутентификации с названием хоста etcd
   - сертификат удостоверения с названием хоста etcd
3. Для каждого хоста-клиента (общее название хоста) создать
   - rsa-ключ для аутентификации с названием хоста клиента
   - сертификат удостоверения с названием хоста клиента

Для автоматизации этого процесса пользуемся очень удобным скриптом, которого мы нашли [здесь](https://habr.com/ru/companies/jetinfosystems/articles/847872/?ysclid=mjwo79l286676759989):

```sh
#!/bin/bash

# Директория для сертификатов:
CERT_DIR="/etc/default/etcd/.tls"
mkdir -p ${CERT_DIR}
cd ${CERT_DIR}

# Создание CA-сертификата:
openssl genrsa -out ca.key 4096
openssl req -x509 -new -key ca.key -days 10000 -out ca.crt -subj "/C=RU/ST=Moscow Region/L=Moscow/O=MyOrg/OU=MyUnit/CN=myorg.com"

# Функция для генерации сертификатов для нод:
generate_cert() {
    NODE_NAME=$1
    NODE_IP=$2

    cat <<EOF > ${CERT_DIR}/${NODE_NAME}.san.conf
[ req ]
default_bits       = 4096
distinguished_name = req_distinguished_name
req_extensions     = req_ext
[ req_distinguished_name ]
countryName                 = RU
stateOrProvinceName         = Moscow Region
localityName                = Moscow
organizationName            = MyOrg
commonName                  = ${NODE_NAME}
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1   = ${NODE_NAME}
IP.1    = ${NODE_IP}
IP.2    = 127.0.0.1
EOF

openssl genrsa -out ${NODE_NAME}.key 4096
openssl req -config ${NODE_NAME}.san.conf -new -key ${NODE_NAME}.key -out ${NODE_NAME}.csr -subj "/C=RU/ST=Moscow Region/L=Moscow/O=MyOrg/CN=${NODE_NAME}"
    openssl x509 -extfile ${NODE_NAME}.san.conf -extensions req_ext -req -in ${NODE_NAME}.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${NODE_NAME}.crt -days 10000

    rm -f ${NODE_NAME}.san.conf ${NODE_NAME}.csr
}

# Список нод etcd и их IP-адресов:
ETCD_NODES=("ubt-pg-aduron-etcd1" "ubt-pg-aduron-etcd2" "ubt-pg-aduron-etcd3")
ETCD_IPS=("192.168.47.10" "192.168.47.20" "192.168.47.30")

# Список нод Patroni и их IP-адресов:
PATRONI_NODES=("ubt-pg-aduron-dbnode1" "ubt-pg-aduron-dbnode2")
PATRONI_IPS=("192.168.56.10" "192.168.56.20")


# Генерация сертификатов для нод etcd:
for i in "${!ETCD_NODES[@]}"; do
generate_cert "${ETCD_NODES[$i]}" "${ETCD_IPS[$i]}"
done

# Генерация сертификатов для нод Patroni:
for i in "${!PATRONI_NODES[@]}"; do
generate_cert "${PATRONI_NODES[$i]}" "${PATRONI_IPS[$i]}"
done

chown -R etcd:etcd ${CERT_DIR}
chmod 600 ${CERT_DIR}/*.key
chmod 644 ${CERT_DIR}/*.crt
```

Самое главное здесь - указание названий серверов:
```sh
# Список нод etcd и их IP-адресов:
ETCD_NODES=("ubt-pg-aduron-etcd1" "ubt-pg-aduron-etcd2" "ubt-pg-aduron-etcd3")
ETCD_IPS=("192.168.47.10" "192.168.47.20" "192.168.47.30")

# Список нод Patroni и их IP-адресов:
PATRONI_NODES=("ubt-pg-aduron-dbnode1" "ubt-pg-aduron-dbnode2")
PATRONI_IPS=("192.168.56.10" "192.168.56.20")
```

В итоге запускаем этот скрипт и получаем сертификаты управления etcd для каждого хоста:
```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ chmod u+x generate_etcd_certs.sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo ./generate_etcd_certs.sh
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-etcd1
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-etcd2
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-etcd3
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-dbnode1
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-dbnode2
Сертификаты успешно сгенерированы и сохранены в /etc/default/etcd/.tls

aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo chown -R etcd:etcd /etc/default/etcd/.tls
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo chmod -R 744 /etc/default/etcd/.tls
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo chmod 600 /etc/default/etcd/.tls/*.key
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo ls -lrt /etc/default/etcd/.tls/
total 52
-rw------- 1 etcd etcd 3272 Jan  2 16:09 ca.key
-rwxr--r-- 1 etcd etcd 2045 Jan  2 16:09 ca.crt
-rw------- 1 etcd etcd 3268 Jan  2 16:09 ubt-pg-aduron-etcd1.key
-rwxr--r-- 1 etcd etcd 2074 Jan  2 16:09 ubt-pg-aduron-etcd1.crt
-rw------- 1 etcd etcd 3272 Jan  2 16:09 ubt-pg-aduron-etcd2.key
-rwxr--r-- 1 etcd etcd 2074 Jan  2 16:09 ubt-pg-aduron-etcd2.crt
-rw------- 1 etcd etcd 3272 Jan  2 16:09 ubt-pg-aduron-etcd3.key
-rwxr--r-- 1 etcd etcd 2074 Jan  2 16:09 ubt-pg-aduron-etcd3.crt
-rw------- 1 etcd etcd 3272 Jan  2 16:09 ubt-pg-aduron-dbnode1.key
-rwxr--r-- 1 etcd etcd 2078 Jan  2 16:09 ubt-pg-aduron-dbnode1.crt
-rw------- 1 etcd etcd 3272 Jan  2 16:09 ubt-pg-aduron-dbnode2.key
-rwxr--r-- 1 etcd etcd   41 Jan  2 16:09 ca.srl
-rwxr--r-- 1 etcd etcd 2078 Jan  2 16:09 ubt-pg-aduron-dbnode2.crt
```

Выглядит отлично, но есть нуансы... Пока с этим всё


#### Создание файла настройки etcd 

По сути это файл, в котором описаны разные параметры управления кластером, такие как хосты, интервал проверки (heartbeat), порты, и конечно же, сертификаты управления которых мы только что создали.
Файл выгладит вот так ( )
```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo vi /etc/default/etcd/ubt-pg-aduron-etcd1.conf.yml
name: ubt-pg-aduron-etcd1 # Изменить на других нодах
data-dir: /var/lib/etcd/default
listen-peer-urls: https://0.0.0.0:2380
listen-client-urls: https://0.0.0.0:2379
advertise-client-urls: https://ubt-pg-aduron-etcd1:2379 # Изменить на других нодах
initial-advertise-peer-urls: https://ubt-pg-aduron-etcd1:2380 # Изменить на других нодах
initial-cluster-token: etcd_scope
initial-cluster: ubt-pg-aduron-etcd1=https://ubt-pg-aduron-etcd1:2380,ubt-pg-aduron-etcd2=https://ubt-pg-aduron-etcd2:2380,ubt-pg-aduron-etcd3=https://ubt-pg-aduron-etcd3:2380
initial-cluster-state: new
election-timeout: 5000
heartbeat-interval: 500
 
client-transport-security:
  cert-file: /etc/default/etcd/.tls/ubt-pg-aduron-etcd1.crt # Изменить на других нодах
  key-file: /etc/default/etcd/.tls/ubt-pg-aduron-etcd1.key
  client-cert-auth: true
  trusted-ca-file: /etc/default/etcd/.tls/ca.crt
 
peer-transport-security:
  cert-file: /etc/default/etcd/.tls/ubt-pg-aduron-etcd1.crt # Изменить на других нодах
  key-file: /etc/default/etcd/.tls/ubt-pg-aduron-etcd1.key
  client-cert-auth: true
  trusted-ca-file: /etc/default/etcd/.tls/ca.crt
```

на каждом хосте нужно менять следующие параметры:
- name
- advertise-client-urls
- initial-advertise-peer-urls
- cert-file / key-file (в разделах *client-transport-security* и *peer-transport-security*)

Всё остальное одинакого по всем хостам.
Создадим сразу 3 файла, которые будут ответчать для разных хостов:
- /etc/default/etcd/ubt-pg-aduron-etcd1.conf.yml
- /etc/default/etcd/ubt-pg-aduron-etcd2.conf.yml
- /etc/default/etcd/ubt-pg-aduron-etcd3.conf.yml

Дальше, чтобы приминать файл настроек для управления службы etcd, добавляем его среди аргументов при запуске службы:
```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo vi /usr/lib/systemd/system/etcd.service
[...]
Environment=DAEMON_ARGS=--config-file=/etc/default/etcd/ubt-pg-aduron-etcd1.conf.yml
[...]
```

Пересчитаем конфиг и перезапускаем службу 
```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo systemctl daemon-reload
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo systemctl restart etcd
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo systemctl status etcd
● etcd.service - etcd - highly-available key value store
     Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-01-02 16:38:17 UTC; 4s ago
       Docs: https://etcd.io/docs
             man:etcd
   Main PID: 16583 (etcd)
      Tasks: 7 (limit: 2267)
     Memory: 21.1M (peak: 21.6M)
        CPU: 203ms
     CGroup: /system.slice/etcd.service
             └─16583 /usr/bin/etcd --config-file=/etc/default/etcd/ubt-pg-aduron-etcd1.conf.yml

Jan 02 16:38:09 ubt-pg-aduron-dbnode1 etcd[16583]: listening for peers on [::]:2380
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: raft2026/01/02 16:38:17 INFO: 8e9e05c52164694d is starting a new election at term 2
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: raft2026/01/02 16:38:17 INFO: 8e9e05c52164694d became candidate at term 3
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: raft2026/01/02 16:38:17 INFO: 8e9e05c52164694d received MsgVoteResp from 8e9e05c52164694d at term 3
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: raft2026/01/02 16:38:17 INFO: 8e9e05c52164694d became leader at term 3
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: raft2026/01/02 16:38:17 INFO: raft.node: 8e9e05c52164694d elected leader 8e9e05c52164694d at term 3
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: published {Name:ubt-pg-aduron-etcd1 ClientURLs:[https://ubt-pg-aduron-etcd1:2379]} to cluster cdf818194e3a8c32
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: ready to serve client requests
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 systemd[1]: Started etcd.service - etcd - highly-available key value store.
Jan 02 16:38:17 ubt-pg-aduron-dbnode1 etcd[16583]: serving client requests on [::]:2379
```

#### Установление клиентских двойчных

В связи с тем, что установили etcd с репозитори приготовленных двойчных, он пока на включает клиенсткой части. Её надо установить отдельно. Что на самом деле простой:

```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo apt install etcd-client
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following NEW packages will be installed:
  etcd-client
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
Need to get 5,295 kB of archives.
After this operation, 17.7 MB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 etcd-client amd64 3.4.30-1ubuntu0.24.04.3 [5,295 kB]
Fetched 5,295 kB in 1s (6,173 kB/s)
Selecting previously unselected package etcd-client.
(Reading database ... 89990 files and directories currently installed.)
Preparing to unpack .../etcd-client_3.4.30-1ubuntu0.24.04.3_amd64.deb ...
Unpacking etcd-client (3.4.30-1ubuntu0.24.04.3) ...
Setting up etcd-client (3.4.30-1ubuntu0.24.04.3) ...
Processing triggers for man-db (2.12.0-4build2) ...
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...

Service restarts being deferred:
 /etc/needrestart/restart.d/dbus.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service

No containers need to be restarted.

User sessions running outdated binaries:
 aduron @ session #1: login[864]
 aduron @ session #3: sshd[1092]
 aduron @ user manager service: systemd[968]

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

Запускаем etcdctl... и ничего не получаем, несмотря на то что etcd ясно запушено:

```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ etcdctl endpoint status -w table
{"level":"warn","ts":"2026-01-02T16:42:32.969985Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc000104380/127.0.0.1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection closed"}
Failed to get the status of endpoint 127.0.0.1:2379 (context deadline exceeded)
+----------+----+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| ENDPOINT | ID | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------+----+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
+----------+----+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$
```

После несколких попыток, становилось понятно что нужно здесь указать
- --cacert (главный сертификат)
- --cert (сертификат хоста)
- --key (ключ сертификата хоста)
- --endpoints (список точек управления кластера)
а потом толко главная команда (endpoint status -w table)
Это выгладит вот так

```sh
sudo etcdctl \
        --cacert=/etc/default/etcd/.tls/ca.crt \
        --cert=/etc/default/etcd/.tls/ubt-pg-aduron-dbnode1.crt \
        --key=/etc/default/etcd/.tls/ubt-pg-aduron-dbnode1.key \
        --endpoints=https://ubt-pg-aduron-etcd1:2379,https://ubt-pg-aduron-etcd2:2379,https://ubt-pg-aduron-etcd3:2379 \
        endpoint status -w table
```

С этим получаем верный статус нашего кластера (который пока составляет из всего одного хоста)
```sh
{"level":"warn","ts":"2026-01-02T16:51:00.699055Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000f8c40/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.20:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd2:2379 (context deadline exceeded)
{"level":"warn","ts":"2026-01-02T16:51:05.700741Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000f8c40/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.30:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd3:2379 (context deadline exceeded)
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|             ENDPOINT             |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://ubt-pg-aduron-etcd1:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |         3 |          6 |                  6 |        |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$
```

Чтобы избавить головную боль с этой командой, можно создать и добавить в bashrc вот следующее alias:
```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ echo 'alias ectl="sudo etcdctl --cacert=/etc/default/etcd/.tls/ca.crt --cert=/etc/default/etcd/.tls/$(hostname).crt --key=/etc/default/etcd/.tls/$(hostname).key --endpoints=https://ubt-pg-aduron-etcd1:2379,https://ubt-pg-aduron-etcd2:2379,https://ubt-pg-aduron-etcd3:2379"' >> ~/.bashrc
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ source ~/.bashrc
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ ectl endpoint status -w table
{"level":"warn","ts":"2026-01-02T16:57:18.627375Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc000007dc0/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.20:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd2:2379 (context deadline exceeded)
{"level":"warn","ts":"2026-01-02T16:57:23.64Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc000007dc0/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.30:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd3:2379 (context deadline exceeded)
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|             ENDPOINT             |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://ubt-pg-aduron-etcd1:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |         3 |          6 |                  6 |        |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

#### Подготовка к клонированию

У нас теперь одна машина польностью готова с точки зреня управления *etcd*.
Чтобы не нужно было повторять всех этих шагов 2 раза, мы можем её клонировать, и перенастройть скриптом, что позволить очень быстро настройть остальные 2 хоста кластера.
Нужно всё таки будет вносить следующие изменения в клонах:

- Сменить название хоста
- Перенастрайвать сеть
- Перенастрайвать службу etcd 

Поэтому создал этот скрипт, с помощью которого можно будет вносить все эти изменения на клонах.

```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts$ vi initiate_node.sh
aduron@ubt-pg-aduron-dbnode1:~/scripts$ chmod +x initiate_node.sh
aduron@ubt-pg-aduron-dbnode2:~/scripts$ cat initiate_node.sh
#!/bin/bash

# Configure hostname
hstnm=$1
hostnamectl set-hostname ${hstnm}

# Configure network
mainnet=$3
etcdnet=$4
sed -i "s/192.168.56.10/${mainnet}/g" /etc/netplan/50-cloud-init.yaml
sed -i "s/192.168.47.10/${etcdnet}/g" /etc/netplan/50-cloud-init.yaml

netplan apply

# Set etcd config file
etcdnm=$2
sed -i "s/ubt-pg-aduron-etcd1/${etcdnm}/g" /usr/lib/systemd/system/etcd.service

systemctl daemon-reload
systemctl restart etcd
```

После этого стопнул первую ВМ.


### 1-ое клонирование виртуалной машины (создвние ubt-pg-aduron-dbnode2)

#### Клонирование ВМ

Для клонирования, выбрать "клонировать...", выбрать новое название ВМ, и как политака МАС-адреса выбрать "сгенерировать новые МАС-адреса всех адаптеров."
На следующем шаге выбрать "полное клонирование". После настравания, запустить машину.

<details>
<summary>Подробности клонирования...</summary>
</br><img src="img/2_vm_clone/clone-1.png" width="800" />
</br><img src="img/2_vm_clone/clone-2.png" width="800" />
</br><img src="img/2_vm_clone/clone-3.png" width="800" />
</br><img src="img/2_vm_clone/clone-4.png" width="800" />
</details>

#### Перенастраивание и проверка

После включения, клон ещё имеет название исходной машины. В консоле управления запускаем зледуюшую команду:

```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts$ sudo ./initiate_node.sh ubt-pg-aduron-dbnode2 ubt-pg-aduron-etcd2 192.168.56.20 192.168.47.20
```

Создаваем новое подключение с новым айпи и пролверяем подключение и переименование:

```sh
Using username "aduron".
Authenticating with public key "rsa-key-20241127"
Welcome to Ubuntu 24.04.3 LTS (GNU/Linux 6.8.0-90-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Fri Jan  2 06:43:15 PM UTC 2026

  System load:  0.0                Processes:               131
  Usage of /:   44.8% of 11.21GB   Users logged in:         1
  Memory usage: 11%                IPv4 address for enp0s3: 10.0.2.15
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status


Last login: Fri Jan  2 18:30:22 2026 from 192.168.56.1
aduron@ubt-pg-aduron-dbnode2:~$
```

Проверяем статус службы etcd и использование правильного файла настроек /etc/default/etcd/ubt-pg-aduron-etcd2.conf.yml

```sh
aduron@ubt-pg-aduron-dbnode2:~/scripts$ sudo systemctl status etcd
[sudo] password for aduron:
● etcd.service - etcd - highly-available key value store
     Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-01-02 18:39:14 UTC; 5min ago
       Docs: https://etcd.io/docs
             man:etcd
   Main PID: 1297 (etcd)
      Tasks: 7 (limit: 2265)
     Memory: 5.4M (peak: 6.3M)
        CPU: 2.412s
     CGroup: /system.slice/etcd.service
             └─1297 /usr/bin/etcd --config-file=/etc/default/etcd/ubt-pg-aduron-etcd2.conf.yml

Jan 02 18:39:12 ubt-pg-aduron-dbnode2 etcd[1297]: listening for peers on [::]:2380
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: raft2026/01/02 18:39:14 INFO: 8e9e05c52164694d is starting a new election at term 7
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: raft2026/01/02 18:39:14 INFO: 8e9e05c52164694d became candidate at term 8
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: raft2026/01/02 18:39:14 INFO: 8e9e05c52164694d received MsgVoteResp from 8e9e05c52164694d at term 8
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: raft2026/01/02 18:39:14 INFO: 8e9e05c52164694d became leader at term 8
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: raft2026/01/02 18:39:14 INFO: raft.node: 8e9e05c52164694d elected leader 8e9e05c52164694d at term 8
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: published {Name:ubt-pg-aduron-etcd2 ClientURLs:[https://ubt-pg-aduron-etcd2:2379]} to cluster cdf818194e3a8c32
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: ready to serve client requests
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 systemd[1]: Started etcd.service - etcd - highly-available key value store.
Jan 02 18:39:14 ubt-pg-aduron-dbnode2 etcd[1297]: serving client requests on [::]:2379
```

Проверяем состояние сети

```sh
aduron@ubt-pg-aduron-dbnode2:~/scripts$ netplan status
     Online state: online
    DNS Addresses: 127.0.0.53 (stub)
       DNS Search: Home

●  1: lo ethernet UNKNOWN/UP (unmanaged)
      MAC Address: 00:00:00:00:00:00
        Addresses: 127.0.0.1/8
                   ::1/128

●  2: enp0s3 ethernet UP (networkd: enp0s3)
      MAC Address: 08:00:27:b1:ab:f3 (Intel Corporation)
        Addresses: 10.0.2.15/24 (dynamic, dhcp)
                   fe80::a00:27ff:feb1:abf3/64 (link)
    DNS Addresses: 192.168.0.1
       DNS Search: Home
           Routes: default via 10.0.2.2 from 10.0.2.15 metric 100 (dhcp)
                   10.0.2.0/24 from 10.0.2.15 metric 100 (link)
                   10.0.2.2 from 10.0.2.15 metric 100 (dhcp, link)
                   192.168.0.1 via 10.0.2.2 from 10.0.2.15 metric 100 (dhcp)
                   fe80::/64 metric 256

●  3: enp0s8 ethernet UP (networkd: enp0s8)
      MAC Address: 08:00:27:ed:3a:6e (Intel Corporation)
        Addresses: 192.168.56.20/24
                   fe80::a00:27ff:feed:3a6e/64 (link)
           Routes: 192.168.56.0/24 from 192.168.56.20 (link)
                   fe80::/64 metric 256

●  4: enp0s9 ethernet UP (networkd: enp0s9)
      MAC Address: 08:00:27:4f:ed:20 (Intel Corporation)
        Addresses: 192.168.47.20/24
                   fe80::a00:27ff:fe4f:ed20/64 (link)
           Routes: 192.168.47.0/24 from 192.168.47.20 (link)
                   fe80::/64 metric 256
```

Проверяем что etcdctl сможет управлять нашим клоном
```sh
aduron@ubt-pg-aduron-dbnode2:~/scripts$ ectl endpoint status -w table
{"level":"warn","ts":"2026-01-02T18:49:07.051602Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc000007c00/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.10:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd1:2379 (context deadline exceeded)
{"level":"warn","ts":"2026-01-02T18:49:12.105871Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc000007c00/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.30:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd3:2379 (context deadline exceeded)
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|             ENDPOINT             |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://ubt-pg-aduron-etcd2:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |         8 |         16 |                 16 |        |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

Отлично. 
Здесь стопним эту ВМ.


### 2-ое клонирование виртуалной машины (создвние ubt-pg-aduron-dbnode3)

#### Клонирование ВМ (повторно)

Здесь просто повторяем шаги клонирования и создаваем ubt-pg-aduron-dbnode3

#### Перенастраивание и проверка

После включения, в консоле управления запускаем зледуюшую команду:

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo ./initiate_node.sh ubt-pg-aduron-dbnode3 ubt-pg-aduron-etcd3 192.168.56.30 192.168.47.30
```

После этого создаваем новое ssh-подключение и проверим состояние.
```sh
aduron@ubt-pg-aduron-dbnode3:~$ netplan status
     Online state: online
    DNS Addresses: 127.0.0.53 (stub)
       DNS Search: Home

●  1: lo ethernet UNKNOWN/UP (unmanaged)
      MAC Address: 00:00:00:00:00:00
        Addresses: 127.0.0.1/8
                   ::1/128

●  2: enp0s3 ethernet UP (networkd: enp0s3)
      MAC Address: 08:00:27:d6:71:26 (Intel Corporation)
        Addresses: 10.0.2.15/24 (dynamic, dhcp)
                   fe80::a00:27ff:fed6:7126/64 (link)
    DNS Addresses: 192.168.0.1
       DNS Search: Home
           Routes: default via 10.0.2.2 from 10.0.2.15 metric 100 (dhcp)
                   10.0.2.0/24 from 10.0.2.15 metric 100 (link)
                   10.0.2.2 from 10.0.2.15 metric 100 (dhcp, link)
                   192.168.0.1 via 10.0.2.2 from 10.0.2.15 metric 100 (dhcp)
                   fe80::/64 metric 256

●  3: enp0s8 ethernet UP (networkd: enp0s8)
      MAC Address: 08:00:27:a2:85:f6 (Intel Corporation)
        Addresses: 192.168.56.30/24
                   fe80::a00:27ff:fea2:85f6/64 (link)
           Routes: 192.168.56.0/24 from 192.168.56.30 (link)
                   fe80::/64 metric 256

●  4: enp0s9 ethernet UP (networkd: enp0s9)
      MAC Address: 08:00:27:2a:7d:d0 (Intel Corporation)
        Addresses: 192.168.47.30/24
                   fe80::a00:27ff:fe2a:7dd0/64 (link)
           Routes: 192.168.47.0/24 from 192.168.47.30 (link)
                   fe80::/64 metric 256

aduron@ubt-pg-aduron-dbnode3:~$ sudo systemctl status etcd
[sudo] password for aduron:
● etcd.service - etcd - highly-available key value store
     Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-01-02 19:04:41 UTC; 2min 26s ago
       Docs: https://etcd.io/docs
             man:etcd
   Main PID: 1359 (etcd)
      Tasks: 7 (limit: 2265)
     Memory: 5.8M (peak: 6.3M)
        CPU: 1.220s
     CGroup: /system.slice/etcd.service
             └─1359 /usr/bin/etcd --config-file=/etc/default/etcd/ubt-pg-aduron-etcd3.conf.yml

Jan 02 19:04:33 ubt-pg-aduron-dbnode3 etcd[1359]: listening for peers on [::]:2380
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: raft2026/01/02 19:04:41 INFO: 8e9e05c52164694d is starting a new election at term 7
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: raft2026/01/02 19:04:41 INFO: 8e9e05c52164694d became candidate at term 8
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: raft2026/01/02 19:04:41 INFO: 8e9e05c52164694d received MsgVoteResp from 8e9e05c52164694d at term 8
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: raft2026/01/02 19:04:41 INFO: 8e9e05c52164694d became leader at term 8
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: raft2026/01/02 19:04:41 INFO: raft.node: 8e9e05c52164694d elected leader 8e9e05c52164694d at term 8
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: published {Name:ubt-pg-aduron-etcd3 ClientURLs:[https://ubt-pg-aduron-etcd3:2379]} to cluster cdf818194e3a8c32
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: ready to serve client requests
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 systemd[1]: Started etcd.service - etcd - highly-available key value store.
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: serving client requests on [::]:2379
```

Всё видимо в порядке... однако не получается запустить etcdctl

```sh
aduron@ubt-pg-aduron-dbnode3:~/scripts/resources$ ectl endpoint status -w table
{"level":"warn","ts":"2026-01-02T19:18:41.441891Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000f9180/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.10:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd1:2379 (context deadline exceeded)
{"level":"warn","ts":"2026-01-02T19:18:46.442804Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000f9180/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.20:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd2:2379 (context deadline exceeded)
{"level":"warn","ts":"2026-01-02T19:18:51.443218Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc0000f9180/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: authentication handshake failed: tls: failed to verify certificate: x509: certificate signed by unknown authority (possibly because of \\\"crypto/rsa: verification error\\\" while trying to verify candidate authority certificate \\\"myorg.com\\\")\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd3:2379 (context deadline exceeded)
+----------+----+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| ENDPOINT | ID | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------+----+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
+----------+----+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

В логах службы:
```sh
Jan 02 19:04:41 ubt-pg-aduron-dbnode3 etcd[1359]: serving client requests on [::]:2379
Jan 02 19:15:19 ubt-pg-aduron-dbnode3 etcd[1359]: rejected connection from "192.168.47.30:54182" (error "remote error: tls: bad certificate", ServerName "ubt-pg-aduron-etcd3")
Jan 02 19:15:20 ubt-pg-aduron-dbnode3 etcd[1359]: rejected connection from "192.168.47.30:54188" (error "remote error: tls: bad certificate", ServerName "ubt-pg-aduron-etcd3")
Jan 02 19:15:22 ubt-pg-aduron-dbnode3 etcd[1359]: rejected connection from "192.168.47.30:54204" (error "remote error: tls: bad certificate", ServerName "ubt-pg-aduron-etcd3")
```

#### вечная борьба с сертификатами

Тут сразу более или менее понятно, что дело в отсутствии сертификата для 3-го сервера. 
Если впомнить, мы сгенерировали сертификаты для этого списка нодов 

```sh
# Список нод etcd и их IP-адресов:
ETCD_NODES=("ubt-pg-aduron-etcd1" "ubt-pg-aduron-etcd2" "ubt-pg-aduron-etcd3")
ETCD_IPS=("192.168.47.10" "192.168.47.20" "192.168.47.30")

# Список нод Patroni и их IP-адресов:
PATRONI_NODES=("ubt-pg-aduron-dbnode1" "ubt-pg-aduron-dbnode2")
PATRONI_IPS=("192.168.56.10" "192.168.56.20")
```

Корошо с точки зрения серверной части etcd, однако здесь отсутсвует название 3-го сервера. Я его не включил в списке так он не является членом кластера Патрони, но его сертификать всё таки надо создать, иначе не возможно запустить подобную команду с этого хоста:

```sh
sudo etcdctl \
        --cacert=/etc/default/etcd/.tls/ca.crt \
        --cert=/etc/default/etcd/.tls/ubt-pg-aduron-dbnode3.crt \
        --key=/etc/default/etcd/.tls/ubt-pg-aduron-dbnode3.key \
        --endpoints=https://ubt-pg-aduron-etcd1:2379,https://ubt-pg-aduron-etcd2:2379,https://ubt-pg-aduron-etcd3:2379 \
        endpoint status -w table
```

##### Попытка исправления №1

Здесь я просто запустил такой же скрипт генерации сертификатоф только с этим хостом.
```sh
# Список нод Patroni и их IP-адресов:
PATRONI_NODES=("ubt-pg-aduron-dbnode3")
PATRONI_IPS=("192.168.56.30")
```
```sh
aduron@ubt-pg-aduron-dbnode3:~/scripts/resources$ sudo ./generate_etcd_certs_node3.sh
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-dbnode3
Сертификаты успешно сгенерированы и сохранены в /etc/default/etcd/.tls
```

*Итог*: такая же ошибка

##### Попытка исправления №2

С трудом впомнил, что решил выбрать другое название сервера. То есть cluster3, а не node3 для отличия тех хосто, которые не примут участие в Patroni
Ладно, не сложно его менять:
```sh
hostnamectl set-hostname ubt-pg-aduron-cluster3
aduron@ubt-pg-aduron-cluster3:~$
```

Далее пересоздал его сертификат.

*Итог*: такая же ошибка

##### Попытка исправления №3

Что то не так. Решил перезоздать сертификат etcd 
```sh
aduron@ubt-pg-aduron-cluster3:~/scripts/resources$ sudo ./generate_etcd_certs_local.sh ubt-pg-aduron-etcd3 192.168.47.30
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-etcd3
Сертификаты успешно сгенерированы и сохранены в /etc/default/etcd/.tls
```

*Итог*: такая же ошибка

##### Попытка исправления №4

Скопировал старые сертификаты CA с первого хоста, так как подозревал, что плохая идея их перегенерировать!
Изменил свой скрипт, чтобы использовать тот cacert, создан на первом хосте.

```sh
aduron@ubt-pg-aduron-cluster3:~/scripts/resources$ sudo cp ./main_certs/ca.* /etc/default/etcd/.tls
aduron@ubt-pg-aduron-cluster3:~/scripts/resources$ vi generate_etcd_certs_local.sh
aduron@ubt-pg-aduron-cluster3:~/scripts/resources$ sudo ./generate_etcd_certs_local.sh ubt-pg-aduron-etcd3 192.168.47.30
Ensure you copied original ca.* files to '/etc/default/etcd/.tls' !!!
Press enter to continue...
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-etcd3
Сертификаты успешно сгенерированы и сохранены в /etc/default/etcd/.tls
```

*Итог*: такая же ошибка


##### Попытка исправления №495

Такая же идея, только
- c хоста *ubt-pg-aduron-dbnode1*
- сгенерировал вместе etcd3 и cluster3
- Используя тот самый первый сгенеривованый cacert 

```sh
aduron@ubt-pg-aduron-dbnode1:~/scripts/resources$ sudo ./generate_etcd_certs_newnode.sh ubt-pg-aduron-cluster3 192.168.56.30 ubt-pg-aduron-etcd3 192.168.47.30
Ensure you copied original ca.* files to '/etc/default/etcd/.tls' !!!
Press enter to continue...
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-etcd3
Certificate request self-signature ok
subject=C = RU, ST = Moscow Region, L = Moscow, O = MyOrg, CN = ubt-pg-aduron-cluster3
Сертификаты успешно сгенерированы и сохранены в /etc/default/etcd/.tls
```

И скопировал их в *ubt-pg-aduron-cluster3*

```sh
aduron@ubt-pg-aduron-cluster3:~/scripts/resources$ ectl endpoint status -w table
{"level":"warn","ts":"2026-01-02T20:40:11.175856Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"etcd-endpoints://0xc000007c00/ubt-pg-aduron-etcd1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = latest balancer error: last connection error: connection error: desc = \"transport: Error while dialing dial tcp 192.168.47.20:2379: connect: no route to host\""}
Failed to get the status of endpoint https://ubt-pg-aduron-etcd2:2379 (context deadline exceeded)
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|             ENDPOINT             |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://ubt-pg-aduron-etcd1:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |         7 |         14 |                 14 |        |
| https://ubt-pg-aduron-etcd3:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |        14 |         28 |                 28 |        |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

Ура!


#### Сформирование единного кластера

После конфигурации третего хоста, остановил все ВМ, затем перезапустил их одновременно. И сформировался такой кластер. С первого взглада как будто работает, но ясно что-то пошел не по плану: тут все участники имеют один и тот же ID (8e9e05c52164694d) что неправильно. Также видно что каждый хост имеет свойство "IS LEADER"=true. По сути, в текущем состоянии кластер ведет себя как будто у нас только один участник с разними точками подключения (endpoint) в зависимости от хоста. 

```sh
aduron@ubt-pg-aduron-dbnode2:~$ ectl endpoint status -w table
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|             ENDPOINT             |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://ubt-pg-aduron-etcd1:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |         8 |         16 |                 16 |        |
| https://ubt-pg-aduron-etcd2:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |        11 |         22 |                 22 |        |
| https://ubt-pg-aduron-etcd3:2379 | 8e9e05c52164694d |  3.4.30 |   20 kB |      true |      false |        15 |         30 |                 30 |        |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

После много времени, пытаясь понимать что здесь произошло, стало понятным что у нас здесь опять таки одно последствие клонирования. Причина в конце концов, нашел [здесь](https://stackoverflow.com/questions/40585943/etcd-cluster-id-mistmatch):

> *Running an etcd instance with "--cluster-state new" at any point, will generate a cluster ID in the data directory. If you try to then/later join an existing cluster, it will use that old generated cluster ID (which is when the mismatch error occurs). Yes, technically the OP had an "old cluster" but more likely, and 100% common, is when someone is trying to stand up their first cluster, they don't notice the procedure has to change. I find that etcd kind of generally fails in providing a good usage model.*

> [!TIP]
> Здесь было принято решение удалить папку "member" на всех серверах (в нашем слушае нашел её в `/var/lib/etcd/default/member`)

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl stop etcd
aduron@ubt-pg-aduron-dbnode1:~$ sudo mv /var/lib/etcd/default/member ~/member.backup

aduron@ubt-pg-aduron-dbnode2:~$ sudo systemctl stop etcd
aduron@ubt-pg-aduron-dbnode2:~$ sudo mv /var/lib/etcd/default/member ~/member.backup

aduron@ubt-pg-aduron-cluster3:~$ sudo systemctl stop etcd
aduron@ubt-pg-aduron-cluster3:~$ sudo mv /var/lib/etcd/default/member ~/member.backup
```

И перезапустил etcd
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl start etcd
aduron@ubt-pg-aduron-dbnode2:~$ sudo systemctl start etcd
aduron@ubt-pg-aduron-cluster3:~$ sudo systemctl start etcd
```

В итоге появилось правильное и ожидаемое состояние кластера:
```sh
aduron@ubt-pg-aduron-dbnode1:~$ ectl endpoint status -w table
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|             ENDPOINT             |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://ubt-pg-aduron-etcd1:2379 | 75ae20a713d9d171 |  3.4.30 |   20 kB |     false |      false |         2 |          8 |                  8 |        |
| https://ubt-pg-aduron-etcd2:2379 | 6e58acf468311e04 |  3.4.30 |   20 kB |      true |      false |         2 |          8 |                  8 |        |
| https://ubt-pg-aduron-etcd3:2379 | 9444b20a64655d13 |  3.4.30 |   20 kB |     false |      false |         2 |          8 |                  8 |        |
+----------------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

> [!TIP]
> Удаление папки *member* стоило бы добавить в скрипте клонирования, чтобы этой проблемы больше не встречать при создании нового клона.


#### Зафикирование существующего кластера

После сформирования, рекомендуется менять следующую настройку 
```sh
initial-cluster-state: existing
```

Настройка была изменена на каждом серсере в этих файлах
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo vi /etc/default/etcd/ubt-pg-aduron-etcd1.conf.yml
aduron@ubt-pg-aduron-dbnode2:~$ sudo vi /etc/default/etcd/ubt-pg-aduron-etcd2.conf.yml
aduron@ubt-pg-aduron-cluster3:~$ sudo vi /etc/default/etcd/ubt-pg-aduron-etcd3.conf.yml
```


#### Итог создания ВМ и кластера etcd

В итоге, несмотря на то, что этот способ установки немножно отличается от того, что могли найти в болшинстве примеров, он точно позволил нам
- Лучше понять механизмы управления кластером
- Секономить немножко времени, и не польностю развернуть все наши сервера с ноля

<details>
<summary>Список ВМ</summary>
</br><img src="img/2_vm_clone/config.png" width="1000" />
</details>


### Настраивание модули управления Patroni

#### Подготовка Постгреса 

Нам приходится отключить службу Постгреса, так как кластером будем управлять Patroni в конце концов.
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl stop postgresql@18-main.service
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl disable postgresql@18-main.service
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl daemon-reload

aduron@ubt-pg-aduron-dbnode2:~/scripts$ sudo systemctl stop postgresql@18-main.service
[sudo] password for aduron:
aduron@ubt-pg-aduron-dbnode2:~/scripts$ sudo systemctl disable postgresql@18-main.service
aduron@ubt-pg-aduron-dbnode2:~/scripts$ sudo systemctl daemon-reload
```

На обоих нодах, создадим пространство для расмешения каталога постгресса. У нас же достато мест осталось в VG.

```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo vgdisplay
  --- Volume group ---
  VG Name               ubuntu-vg
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  2
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               1
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               <23.00 GiB
  PE Size               4.00 MiB
  Total PE              5887
  Alloc PE / Size       2943 / <11.50 GiB
  Free  PE / Size       2944 / 11.50 GiB
  VG UUID               aCKgUM-D4Sh-byJs-4NnY-Jp2w-sJLL-Ac7T90
```
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo lvcreate -l 80%FREE -n lv-pgcatalog-01 ubuntu-vg
  Logical volume "lv-pgcatalog-01" created.
aduron@ubt-pg-aduron-dbnode2:~$ sudo lvcreate -l 80%FREE -n lv-pgcatalog-01 ubuntu-vg
  Logical volume "lv-pgcatalog-01" created.
```
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo mkfs.ext4 /dev/ubuntu-vg/lv-pgcatalog-01
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 2411520 4k blocks and 603840 inodes
Filesystem UUID: 56247dc7-02e7-4a83-8dd3-51b79b92bc5c
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done
Writing inode tables: done
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done

aduron@ubt-pg-aduron-dbnode2:~$ sudo mkfs.ext4 /dev/ubuntu-vg/lv-pgcatalog-01
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 2411520 4k blocks and 603840 inodes
Filesystem UUID: 51d00d46-57d9-499c-841a-b8e5921a7596
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done
Writing inode tables: done
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done
```
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo mkdir /mnt/data
aduron@ubt-pg-aduron-dbnode1:~$ sudo mount /dev/ubuntu-vg/lv-pgcatalog-01 /mnt/data
aduron@ubt-pg-aduron-dbnode1:~$ sudo chown -R postgres:postgres /mnt/data/

aduron@ubt-pg-aduron-dbnode2:~$ sudo mkdir /mnt/data
aduron@ubt-pg-aduron-dbnode2:~$ sudo mount /dev/ubuntu-vg/lv-pgcatalog-01 /mnt/data
aduron@ubt-pg-aduron-dbnode2:~$ sudo chown -R postgres:postgres /mnt/data/
```

> [!WARNING]
> Не забывать добавить его в fstab для автоматичного смонтирования после перезагрузки
```sh
aduron@ubt-pg-aduron-dbnode1:~$ ls -lrt /dev/disk/by-uuid/
total 0
lrwxrwxrwx 1 root root 10 Jan 16 16:40 221a5c77-adde-4fdb-93df-b9994bfb9798 -> ../../sda2
lrwxrwxrwx 1 root root 10 Jan 16 16:40 74f57005-3b9a-4ec7-a82d-31e921387bef -> ../../dm-0
lrwxrwxrwx 1 root root 10 Jan 16 18:49 56247dc7-02e7-4a83-8dd3-51b79b92bc5c -> ../../dm-1 <<

# Added this line
/dev/disk/by-uuid/56247dc7-02e7-4a83-8dd3-51b79b92bc5c /mnt/data ext4 defaults 0 1

# Ребут для проверки
aduron@ubt-pg-aduron-dbnode1:~$ sudo reboot

Broadcast message from root@ubt-pg-aduron-dbnode1 on pts/1 (Fri 2026-01-16 19:02:48 UTC):

The system will reboot now!

aduron@ubt-pg-aduron-dbnode1:~$ df -h
Filesystem                                Size  Used Avail Use% Mounted on
tmpfs                                     197M  1.1M  196M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv          12G  5.2G  5.5G  49% /
tmpfs                                     984M  1.1M  983M   1% /dev/shm
tmpfs                                     5.0M     0  5.0M   0% /run/lock
/dev/mapper/ubuntu--vg-lv--pgcatalog--01  9.0G   24K  8.5G   1% /mnt/data
/dev/sda2                                 2.0G  102M  1.7G   6% /boot
tmpfs                                     197M   12K  197M   1% /run/user/1000
```

Затем перемещаем каталог постгреса

```sh
postgres@ubt-pg-aduron-dbnode1:~$ cd /mnt/data
postgres@ubt-pg-aduron-dbnode1:/mnt/data$ mkdir postgresql
postgres@ubt-pg-aduron-dbnode1:/mnt/data$ mv /var/lib/postgresql/18 /mnt/data/postgresql
postgres@ubt-pg-aduron-dbnode1:/mnt/data$ ls -lrt /mnt/data/postgresql
total 4
drwxr-xr-x 3 postgres postgres 4096 Jan  2 14:38 18

postgres@ubt-pg-aduron-dbnode2:~$ cd /mnt/data
postgres@ubt-pg-aduron-dbnode2:/mnt/data$ mkdir postgresql
postgres@ubt-pg-aduron-dbnode2:/mnt/data$ mv /var/lib/postgresql/18 /mnt/data/postgresql
postgres@ubt-pg-aduron-dbnode2:/mnt/data$ ls -lrt /mnt/data/postgresql
total 4
drwxr-xr-x 3 postgres postgres 4096 Jan  2 14:38 18
```
```sh
postgres@ubt-pg-aduron-dbnode1:/mnt/data$ cp /etc/postgresql/18/main/postgresql.conf /etc/postgresql/18/main/postgresql.conf.backup
grep data_directory /etc/postgresql/18/main/postgresql.conf

postgres@ubt-pg-aduron-dbnode1:/mnt/data$ grep data_directory /etc/postgresql/18/main/postgresql.conf
data_directory = '/var/lib/postgresql/18/main'          # use data in another directory
postgres@ubt-pg-aduron-dbnode1:/mnt/data$ sed -i 's/\/var\/lib\/postgresql\/18\/main/\/mnt\/data\/postgresql\/18\/main/g' /etc/postgresql/18/main/postgresql.conf
postgres@ubt-pg-aduron-dbnode1:/mnt/data$ grep data_directory /etc/postgresql/18/main/postgresql.conf
data_directory = '/mnt/data/postgresql/18/main'         # use data in another directory

postgres@ubt-pg-aduron-dbnode2:/mnt/data$ cp /etc/postgresql/18/main/postgresql.conf /etc/postgresql/18/main/postgresql.conf.backup
postgres@ubt-pg-aduron-dbnode2:/mnt/data$ grep data_directory /etc/postgresql/18/main/postgresql.conf
data_directory = '/var/lib/postgresql/18/main'          # use data in another directory
postgres@ubt-pg-aduron-dbnode2:/mnt/data$ sed -i 's/\/var\/lib\/postgresql\/18\/main/\/mnt\/data\/postgresql\/18\/main/g' /etc/postgresql/18/main/postgresql.conf
postgres@ubt-pg-aduron-dbnode2:/mnt/data$ grep data_directory /etc/postgresql/18/main/postgresql.conf
data_directory = '/mnt/data/postgresql/18/main'         # use data in another directory

postgres@ubt-pg-aduron-dbnode1:/mnt/data$ pg_lsclusters
Ver Cluster Port Status Owner    Data directory               Log file
18  main    5432 down   postgres /mnt/data/postgresql/18/main /var/log/postgresql/postgresql-18-main.log
```

#### Установка Patroni

Во первых требуется копирование сертификатов, каоторые были созданны для коммуникации с etcd. Разместим их в /opt/patroni/.tls на каждой ВМ
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo mkdir -p /opt/patroni/.tls
[sudo] password for aduron:
aduron@ubt-pg-aduron-dbnode2:~$ sudo mkdir -p /opt/patroni/.tls

aduron@ubt-pg-aduron-dbnode1:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode1.crt /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode1:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode1.key /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode1:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode2.crt /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode1:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode2.key /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode1:~$ sudo cp /etc/default/etcd/.tls/ca.crt /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode1:~$ sudo cp /etc/default/etcd/.tls/ca.key /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode1:~$ sudo chmod -R 744 /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode1:~$ sudo chmod 600 /opt/patroni/.tls/*.key
aduron@ubt-pg-aduron-dbnode1:~$ sudo ls -lrt /opt/patroni/.tls
total 24
-rwxr--r-- 1 postgres postgres 2078 Jan 16 19:09 ubt-pg-aduron-dbnode1.crt
-rw------- 1 postgres postgres 3272 Jan 16 19:09 ubt-pg-aduron-dbnode1.key
-rwxr--r-- 1 postgres postgres 2078 Jan 16 19:13 ubt-pg-aduron-dbnode2.crt
-rw------- 1 postgres postgres 3272 Jan 16 19:13 ubt-pg-aduron-dbnode2.key
-rwxr--r-- 1 root     root     2045 Jan 16 21:00 ca.crt
-rw------- 1 root     root     3272 Jan 16 21:00 ca.key

aduron@ubt-pg-aduron-dbnode2:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode2.crt /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode2:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode2.key /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode2:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode1.crt /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode2:~$ sudo cp /etc/default/etcd/.tls/ubt-pg-aduron-dbnode1.key /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode2:~$ sudo chmod -R 744 /opt/patroni/.tls
aduron@ubt-pg-aduron-dbnode2:~$ sudo chmod 600 /opt/patroni/.tls/*.key
aduron@ubt-pg-aduron-dbnode2:~$ sudo ls -lrt /opt/patroni/.tls
total 24
-rwxr--r-- 1 postgres postgres 2078 Jan 16 19:10 ubt-pg-aduron-dbnode2.crt
-rw------- 1 postgres postgres 3272 Jan 16 19:10 ubt-pg-aduron-dbnode2.key
-rwxr--r-- 1 postgres postgres 2078 Jan 16 19:14 ubt-pg-aduron-dbnode1.crt
-rw------- 1 postgres postgres 3272 Jan 16 19:14 ubt-pg-aduron-dbnode1.key
-rwxr--r-- 1 root     root     2045 Jan 16 21:01 ca.crt
-rw------- 1 root     root     3272 Jan 16 21:01 ca.key
```

Затем надо установить Python (на базе которого создан модуль Patroni). Ubuntu 24.04 уже приходит с версией Python 3.12, однако отсутствует PIP. Мы его установим вот так на каждой ВМ.
```sh
aduron@ubt-pg-aduron-dbnode2:~$ which pip
aduron@ubt-pg-aduron-dbnode2:~$ which pip3
aduron@ubt-pg-aduron-dbnode2:~$ sudo apt install pip
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Note, selecting 'python3-pip' instead of 'pip'
The following packages were automatically installed and are no longer required:
  dns-root-data dnsmasq-base libbluetooth3 libndp0 libnm0 libteamdctl0 ppp pptp-linux
Use 'sudo apt autoremove' to remove them.
The following additional packages will be installed:
  binutils binutils-common binutils-x86-64-linux-gnu build-essential bzip2 cpp cpp-13 cpp-13-x86-64-linux-gnu cpp-x86-64-linux-gnu dpkg-dev fakeroot g++ g++-13 g++-13-x86-64-linux-gnu g++-x86-64-linux-gnu
  gcc gcc-13 gcc-13-base gcc-13-x86-64-linux-gnu gcc-x86-64-linux-gnu javascript-common libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libasan8 libatomic1 libbinutils libcc1-0
  libctf-nobfd0 libctf0 libdpkg-perl libexpat1-dev libfakeroot libfile-fcntllock-perl libgcc-13-dev libgomp1 libgprofng0 libhwasan0 libisl23 libitm1 libjs-jquery libjs-sphinxdoc libjs-underscore liblsan0
  libmpc3 libpython3-dev libpython3.12-dev libquadmath0 libsframe1 libstdc++-13-dev libtsan2 libubsan1 lto-disabled-list make python3-dev python3-wheel python3.12-dev zlib1g-dev
Suggested packages:
  binutils-doc gprofng-gui bzip2-doc cpp-doc gcc-13-locales cpp-13-doc debian-keyring g++-multilib g++-13-multilib gcc-13-doc gcc-multilib autoconf automake libtool flex bison gdb gcc-doc gcc-13-multilib
  gdb-x86-64-linux-gnu apache2 | lighttpd | httpd bzr libstdc++-13-doc make-doc
The following NEW packages will be installed:
  binutils binutils-common binutils-x86-64-linux-gnu build-essential bzip2 cpp cpp-13 cpp-13-x86-64-linux-gnu cpp-x86-64-linux-gnu dpkg-dev fakeroot g++ g++-13 g++-13-x86-64-linux-gnu g++-x86-64-linux-gnu
  gcc gcc-13 gcc-13-base gcc-13-x86-64-linux-gnu gcc-x86-64-linux-gnu javascript-common libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libasan8 libatomic1 libbinutils libcc1-0
  libctf-nobfd0 libctf0 libdpkg-perl libexpat1-dev libfakeroot libfile-fc
  ...
  
aduron@ubt-pg-aduron-dbnode2:~$ pip3 -V
pip 24.0 from /usr/lib/python3/dist-packages/pip (python 3.12)
```

Очень желательно установить Patroni в виртуальной среде, что позволит выстро разварачивать новую среду, не трогая основной системы.
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo apt install python3.12-venv
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages were automatically installed and are no longer required:
  dns-root-data dnsmasq-base libbluetooth3 libndp0 libnm0 libteamdctl0 ppp pptp-linux
Use 'sudo apt autoremove' to remove them.
The following additional packages will be installed:
  python3-pip-whl python3-setuptools-whl
The following NEW packages will be installed:
  python3-pip-whl python3-setuptools-whl python3.12-venv
0 upgraded, 3 newly installed, 0 to remove and 2 not upgraded.
Need to get 2,429 kB of archives.
After this operation, 2,777 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 python3-pip-whl all 24.0+dfsg-1ubuntu1.3 [1,707 kB]
Get:2 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 python3-setuptools-whl all 68.1.2-2ubuntu1.2 [716 kB]
Get:3 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 python3.12-venv amd64 3.12.3-1ubuntu0.10 [5,678 B]
Fetched 2,429 kB in 3s (949 kB/s)
Selecting previously unselected package python3-pip-whl.
(Reading database ... 93661 files and directories currently installed.)
Preparing to unpack .../python3-pip-whl_24.0+dfsg-1ubuntu1.3_all.deb ...
Unpacking python3-pip-whl (24.0+dfsg-1ubuntu1.3) ...
Selecting previously unselected package python3-setuptools-whl.
Preparing to unpack .../python3-setuptools-whl_68.1.2-2ubuntu1.2_all.deb ...
Unpacking python3-setuptools-whl (68.1.2-2ubuntu1.2) ...
Selecting previously unselected package python3.12-venv.
Preparing to unpack .../python3.12-venv_3.12.3-1ubuntu0.10_amd64.deb ...
Unpacking python3.12-venv (3.12.3-1ubuntu0.10) ...
Setting up python3-setuptools-whl (68.1.2-2ubuntu1.2) ...
Setting up python3-pip-whl (24.0+dfsg-1ubuntu1.3) ...
Setting up python3.12-venv (3.12.3-1ubuntu0.10) ...
Scanning processes...
Scanning candidates...
Scanning linux images...

Running kernel seems to be up-to-date.

Restarting services...

Service restarts being deferred:
 systemctl restart unattended-upgrades.service

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

Создание виртуальной среды
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo python3 -m venv /opt/patroni
aduron@ubt-pg-aduron-dbnode2:~$ sudo python3 -m venv /opt/patroni

(patroni) aduron@ubt-pg-aduron-dbnode1:/opt/patroni/packages$ sudo chown -R postgres:postgres /opt/patroni
(patroni) aduron@ubt-pg-aduron-dbnode1:/opt/patroni/packages$ sudo su - postgres
postgres@ubt-pg-aduron-dbnode1:~$ source /opt/patroni/bin/activate
(patroni) postgres@ubt-pg-aduron-dbnode1:~$

(patroni) aduron@ubt-pg-aduron-dbnode2:/opt/patroni/packages$ sudo chown -R postgres:postgres /opt/patroni
(patroni) aduron@ubt-pg-aduron-dbnode2:/opt/patroni/packages$ sudo su - postgres
postgres@ubt-pg-aduron-dbnode2:~$ source /opt/patroni/bin/activate
(patroni) postgres@ubt-pg-aduron-dbnode2:~$
```

> [!CAUTION]
> В неких примерах встречается устоновку разных пакетов (python3-psycopg2...) однако на [официальном сайте Патрони](https://patroni.readthedocs.io/en/latest/installation.html), видно что можно установить одновременно все нужные модули следуюшим образом: `pip install patroni[psycopg3,etcd3]`.

```sh 
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ which pip
/opt/patroni/bin/pip
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ pip install patroni[psycopg3,etcd3]
Collecting patroni[etcd3,psycopg3]
  Downloading patroni-4.1.0-py3-none-any.whl.metadata (12 kB)
Collecting urllib3!=1.21,>=1.19.1 (from patroni[etcd3,psycopg3])
  Downloading urllib3-2.6.3-py3-none-any.whl.metadata (6.9 kB)
Collecting PyYAML (from patroni[etcd3,psycopg3])
  Downloading pyyaml-6.0.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl.metadata (2.4 kB)
Collecting py-consul>=1.1.1 (from patroni[etcd3,psycopg3])
  Downloading py_consul-1.7.1-py2.py3-none-any.whl.metadata (6.5 kB)
Collecting click>=5.0 (from patroni[etcd3,psycopg3])
  Downloading click-8.3.1-py3-none-any.whl.metadata (2.6 kB)
Collecting prettytable>=0.7 (from patroni[etcd3,psycopg3])
  Downloading prettytable-3.17.0-py3-none-any.whl.metadata (34 kB)
Collecting python-dateutil (from patroni[etcd3,psycopg3])
  Downloading python_dateutil-2.9.0.post0-py2.py3-none-any.whl.metadata (8.4 kB)
Collecting psutil>=2.0.0 (from patroni[etcd3,psycopg3])
  Downloading psutil-7.2.1-cp36-abi3-manylinux2010_x86_64.manylinux_2_12_x86_64.manylinux_2_28_x86_64.whl.metadata (22 kB)
Collecting ydiff!=1.4.0,!=1.4.1,<1.5,>=1.2.0 (from patroni[etcd3,psycopg3])
  Downloading ydiff-1.4.2.tar.gz (16 kB)
  Installing build dependencies ... done
  Getting requirements to build wheel ... done
  Preparing metadata (pyproject.toml) ... done
Collecting python-etcd<0.5,>=0.4.3 (from patroni[etcd3,psycopg3])
  Downloading python-etcd-0.4.5.tar.gz (37 kB)
  Installing build dependencies ... done
  Getting requirements to build wheel ... done
  Preparing metadata (pyproject.toml) ... done
Collecting psycopg>=3.0.0 (from psycopg[binary]>=3.0.0; extra == "psycopg3"->patroni[etcd3,psycopg3])
  Downloading psycopg-3.3.2-py3-none-any.whl.metadata (4.3 kB)
Collecting wcwidth (from prettytable>=0.7->patroni[etcd3,psycopg3])
  Downloading wcwidth-0.2.14-py2.py3-none-any.whl.metadata (15 kB)
Collecting typing-extensions>=4.6 (from psycopg>=3.0.0->psycopg[binary]>=3.0.0; extra == "psycopg3"->patroni[etcd3,psycopg3])
  Downloading typing_extensions-4.15.0-py3-none-any.whl.metadata (3.3 kB)
Collecting psycopg-binary==3.3.2 (from psycopg[binary]>=3.0.0; extra == "psycopg3"->patroni[etcd3,psycopg3])
  Downloading psycopg_binary-3.3.2-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl.metadata (2.7 kB)
Collecting requests>=2.0 (from py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading requests-2.32.5-py3-none-any.whl.metadata (4.9 kB)
Collecting dnspython>=1.13.0 (from python-etcd<0.5,>=0.4.3->patroni[etcd3,psycopg3])
  Downloading dnspython-2.8.0-py3-none-any.whl.metadata (5.7 kB)
Collecting six>=1.5 (from python-dateutil->patroni[etcd3,psycopg3])
  Downloading six-1.17.0-py2.py3-none-any.whl.metadata (1.7 kB)
Collecting charset_normalizer<4,>=2 (from requests>=2.0->py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading charset_normalizer-3.4.4-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl.metadata (37 kB)
Collecting idna<4,>=2.5 (from requests>=2.0->py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading idna-3.11-py3-none-any.whl.metadata (8.4 kB)
Collecting certifi>=2017.4.17 (from requests>=2.0->py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading certifi-2026.1.4-py3-none-any.whl.metadata (2.5 kB)
Downloading click-8.3.1-py3-none-any.whl (108 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 108.3/108.3 kB 1.1 MB/s eta 0:00:00
Downloading prettytable-3.17.0-py3-none-any.whl (34 kB)
Downloading psutil-7.2.1-cp36-abi3-manylinux2010_x86_64.manylinux_2_12_x86_64.manylinux_2_28_x86_64.whl (154 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 154.7/154.7 kB 2.0 MB/s eta 0:00:00
Downloading psycopg-3.3.2-py3-none-any.whl (212 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 212.8/212.8 kB 2.7 MB/s eta 0:00:00
Downloading psycopg_binary-3.3.2-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl (5.1 MB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 5.1/5.1 MB 14.2 MB/s eta 0:00:00
Downloading py_consul-1.7.1-py2.py3-none-any.whl (38 kB)
Downloading urllib3-2.6.3-py3-none-any.whl (131 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 131.6/131.6 kB 4.4 MB/s eta 0:00:00
Downloading patroni-4.1.0-py3-none-any.whl (372 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 373.0/373.0 kB 13.8 MB/s eta 0:00:00
Downloading python_dateutil-2.9.0.post0-py2.py3-none-any.whl (229 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 229.9/229.9 kB 9.0 MB/s eta 0:00:00
Downloading pyyaml-6.0.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl (807 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 807.9/807.9 kB 14.6 MB/s eta 0:00:00
Downloading dnspython-2.8.0-py3-none-any.whl (331 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 331.1/331.1 kB 15.1 MB/s eta 0:00:00
Downloading requests-2.32.5-py3-none-any.whl (64 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 64.7/64.7 kB 4.2 MB/s eta 0:00:00
Downloading six-1.17.0-py2.py3-none-any.whl (11 kB)
Downloading typing_extensions-4.15.0-py3-none-any.whl (44 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 44.6/44.6 kB 3.0 MB/s eta 0:00:00
Downloading wcwidth-0.2.14-py2.py3-none-any.whl (37 kB)
Downloading certifi-2026.1.4-py3-none-any.whl (152 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 152.9/152.9 kB 5.1 MB/s eta 0:00:00
Downloading charset_normalizer-3.4.4-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl (153 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 153.5/153.5 kB 10.4 MB/s eta 0:00:00
Downloading idna-3.11-py3-none-any.whl (71 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 71.0/71.0 kB 7.1 MB/s eta 0:00:00
Building wheels for collected packages: python-etcd, ydiff
  Building wheel for python-etcd (pyproject.toml) ... done
  Created wheel for python-etcd: filename=python_etcd-0.4.5-py3-none-any.whl size=38534 sha256=d06b54348f9269da1b64e1e6a8aacd4e5a72cc1905951cd2bb9535b4e591a76e
  Stored in directory: /var/lib/postgresql/.cache/pip/wheels/4e/39/67/0e2eeecadaa1efd2710965303e5eff653dd660a24bdcbfb88f
  Building wheel for ydiff (pyproject.toml) ... done
  Created wheel for ydiff: filename=ydiff-1.4.2-py3-none-any.whl size=16306 sha256=3ad808da99f58796ab02292dc3fbd5bfddf1a601d3ff26dc3e7b53e88d1c17a9
  Stored in directory: /var/lib/postgresql/.cache/pip/wheels/00/23/0d/b65d57876592e23aeee7fc7e4e8384f3dff041f3ba208a9cec
Successfully built python-etcd ydiff
Installing collected packages: ydiff, wcwidth, urllib3, typing-extensions, six, PyYAML, psycopg-binary, psutil, idna, dnspython, click, charset_normalizer, certifi, requests, python-etcd, python-dateutil, psycopg, prettytable, py-consul, patroni
Successfully installed PyYAML-6.0.3 certifi-2026.1.4 charset_normalizer-3.4.4 click-8.3.1 dnspython-2.8.0 idna-3.11 patroni-4.1.0 prettytable-3.17.0 psutil-7.2.1 psycopg-3.3.2 psycopg-binary-3.3.2 py-consul-1.7.1 python-dateutil-2.9.0.post0 python-etcd-0.4.5 requests-2.32.5 six-1.17.0 typing-extensions-4.15.0 urllib3-2.6.3 wcwidth-0.2.14 ydiff-1.4.2


(patroni) postgres@ubt-pg-aduron-dbnode2:~$ which pip
/opt/patroni/bin/pip
(patroni) postgres@ubt-pg-aduron-dbnode2:/opt/patroni$ pip install patroni[psycopg3,etcd3]
Collecting patroni[etcd3,psycopg3]
  Downloading patroni-4.1.0-py3-none-any.whl.metadata (12 kB)
Collecting urllib3!=1.21,>=1.19.1 (from patroni[etcd3,psycopg3])
  Downloading urllib3-2.6.3-py3-none-any.whl.metadata (6.9 kB)
Collecting PyYAML (from patroni[etcd3,psycopg3])
  Downloading pyyaml-6.0.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl.metadata (2.4 kB)
Collecting py-consul>=1.1.1 (from patroni[etcd3,psycopg3])
  Downloading py_consul-1.7.1-py2.py3-none-any.whl.metadata (6.5 kB)
Collecting click>=5.0 (from patroni[etcd3,psycopg3])
  Downloading click-8.3.1-py3-none-any.whl.metadata (2.6 kB)
Collecting prettytable>=0.7 (from patroni[etcd3,psycopg3])
  Downloading prettytable-3.17.0-py3-none-any.whl.metadata (34 kB)
Collecting python-dateutil (from patroni[etcd3,psycopg3])
  Downloading python_dateutil-2.9.0.post0-py2.py3-none-any.whl.metadata (8.4 kB)
Collecting psutil>=2.0.0 (from patroni[etcd3,psycopg3])
  Downloading psutil-7.2.1-cp36-abi3-manylinux2010_x86_64.manylinux_2_12_x86_64.manylinux_2_28_x86_64.whl.metadata (22 kB)
Collecting ydiff!=1.4.0,!=1.4.1,<1.5,>=1.2.0 (from patroni[etcd3,psycopg3])
  Downloading ydiff-1.4.2.tar.gz (16 kB)
  Installing build dependencies ... done
  Getting requirements to build wheel ... done
  Preparing metadata (pyproject.toml) ... done
Collecting python-etcd<0.5,>=0.4.3 (from patroni[etcd3,psycopg3])
  Downloading python-etcd-0.4.5.tar.gz (37 kB)
  Installing build dependencies ... done
  Getting requirements to build wheel ... done
  Preparing metadata (pyproject.toml) ... done
Collecting psycopg>=3.0.0 (from psycopg[binary]>=3.0.0; extra == "psycopg3"->patroni[etcd3,psycopg3])
  Downloading psycopg-3.3.2-py3-none-any.whl.metadata (4.3 kB)
Collecting wcwidth (from prettytable>=0.7->patroni[etcd3,psycopg3])
  Downloading wcwidth-0.2.14-py2.py3-none-any.whl.metadata (15 kB)
Collecting typing-extensions>=4.6 (from psycopg>=3.0.0->psycopg[binary]>=3.0.0; extra == "psycopg3"->patroni[etcd3,psycopg3])
  Downloading typing_extensions-4.15.0-py3-none-any.whl.metadata (3.3 kB)
Collecting psycopg-binary==3.3.2 (from psycopg[binary]>=3.0.0; extra == "psycopg3"->patroni[etcd3,psycopg3])
  Downloading psycopg_binary-3.3.2-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl.metadata (2.7 kB)
Collecting requests>=2.0 (from py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading requests-2.32.5-py3-none-any.whl.metadata (4.9 kB)
Collecting dnspython>=1.13.0 (from python-etcd<0.5,>=0.4.3->patroni[etcd3,psycopg3])
  Downloading dnspython-2.8.0-py3-none-any.whl.metadata (5.7 kB)
Collecting six>=1.5 (from python-dateutil->patroni[etcd3,psycopg3])
  Downloading six-1.17.0-py2.py3-none-any.whl.metadata (1.7 kB)
Collecting charset_normalizer<4,>=2 (from requests>=2.0->py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading charset_normalizer-3.4.4-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl.metadata (37 kB)
Collecting idna<4,>=2.5 (from requests>=2.0->py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading idna-3.11-py3-none-any.whl.metadata (8.4 kB)
Collecting certifi>=2017.4.17 (from requests>=2.0->py-consul>=1.1.1->patroni[etcd3,psycopg3])
  Downloading certifi-2026.1.4-py3-none-any.whl.metadata (2.5 kB)
Downloading click-8.3.1-py3-none-any.whl (108 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 108.3/108.3 kB 1.5 MB/s eta 0:00:00
Downloading prettytable-3.17.0-py3-none-any.whl (34 kB)
Downloading psutil-7.2.1-cp36-abi3-manylinux2010_x86_64.manylinux_2_12_x86_64.manylinux_2_28_x86_64.whl (154 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 154.7/154.7 kB 2.5 MB/s eta 0:00:00
Downloading psycopg-3.3.2-py3-none-any.whl (212 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 212.8/212.8 kB 4.9 MB/s eta 0:00:00
Downloading psycopg_binary-3.3.2-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl (5.1 MB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 5.1/5.1 MB 16.4 MB/s eta 0:00:00
Downloading py_consul-1.7.1-py2.py3-none-any.whl (38 kB)
Downloading urllib3-2.6.3-py3-none-any.whl (131 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 131.6/131.6 kB 4.5 MB/s eta 0:00:00
Downloading patroni-4.1.0-py3-none-any.whl (372 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 373.0/373.0 kB 10.2 MB/s eta 0:00:00
Downloading python_dateutil-2.9.0.post0-py2.py3-none-any.whl (229 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 229.9/229.9 kB 7.2 MB/s eta 0:00:00
Downloading pyyaml-6.0.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl (807 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 807.9/807.9 kB 22.8 MB/s eta 0:00:00
Downloading dnspython-2.8.0-py3-none-any.whl (331 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 331.1/331.1 kB 31.2 MB/s eta 0:00:00
Downloading requests-2.32.5-py3-none-any.whl (64 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 64.7/64.7 kB 5.3 MB/s eta 0:00:00
Downloading six-1.17.0-py2.py3-none-any.whl (11 kB)
Downloading typing_extensions-4.15.0-py3-none-any.whl (44 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 44.6/44.6 kB 4.1 MB/s eta 0:00:00
Downloading wcwidth-0.2.14-py2.py3-none-any.whl (37 kB)
Downloading certifi-2026.1.4-py3-none-any.whl (152 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 152.9/152.9 kB 11.4 MB/s eta 0:00:00
Downloading charset_normalizer-3.4.4-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl (153 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 153.5/153.5 kB 16.5 MB/s eta 0:00:00
Downloading idna-3.11-py3-none-any.whl (71 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 71.0/71.0 kB 2.9 MB/s eta 0:00:00
Building wheels for collected packages: python-etcd, ydiff
  Building wheel for python-etcd (pyproject.toml) ... done
  Created wheel for python-etcd: filename=python_etcd-0.4.5-py3-none-any.whl size=38534 sha256=7bd9b31abd142a8ddab548cc983b4e24e83567b988901c36016a5483e4a41a32
  Stored in directory: /var/lib/postgresql/.cache/pip/wheels/4e/39/67/0e2eeecadaa1efd2710965303e5eff653dd660a24bdcbfb88f
  Building wheel for ydiff (pyproject.toml) ... done
  Created wheel for ydiff: filename=ydiff-1.4.2-py3-none-any.whl size=16306 sha256=97d98eb95db85adbc47d60e4b48c9589bfd522adabf8e138598b133a6e25f598
  Stored in directory: /var/lib/postgresql/.cache/pip/wheels/00/23/0d/b65d57876592e23aeee7fc7e4e8384f3dff041f3ba208a9cec
Successfully built python-etcd ydiff
Installing collected packages: ydiff, wcwidth, urllib3, typing-extensions, six, PyYAML, psycopg-binary, psutil, idna, dnspython, click, charset_normalizer, certifi, requests, python-etcd, python-dateutil, psycopg, prettytable, py-consul, patroni
Successfully installed PyYAML-6.0.3 certifi-2026.1.4 charset_normalizer-3.4.4 click-8.3.1 dnspython-2.8.0 idna-3.11 patroni-4.1.0 prettytable-3.17.0 psutil-7.2.1 psycopg-3.3.2 psycopg-binary-3.3.2 py-consul-1.7.1 python-dateutil-2.9.0.post0 python-etcd-0.4.5 requests-2.32.5 six-1.17.0 typing-extensions-4.15.0 urllib3-2.6.3 wcwidth-0.2.14 ydiff-1.4.2
```

#### Создание конфигурации

> [!TIP]
> С помощью `patroni --generate-config` можно создать файл настроек Patroni, однако трубуется ременно запустить кластер.

На каждом ноде, создаваем папку `/etc/patroni`
```sh
aduron@ubt-pg-aduron-dbnode2:~$ sudo mkdir /etc/patroni
[sudo] password for aduron:
aduron@ubt-pg-aduron-dbnode2:~$ sudo chown postgres:postgres /etc/patroni
```
Запускаем `patroni --generate-config` и скопируем результат с */etc/patroni/config.yml*
```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patroni --generate-config 
Please enter the user password:
```

Здесь описано, какие параметры были добавлены, в целом это касается:
- Название кластера
- Местоположение логфайлов и их настройки
- сертификаты управления DCS (для взаймодействия с etcd)
- Кастройки репликации
- use_pg_rewind
- Настройки файла pg_hba
- Учетки для репликации и т.д.
- config_file / hba_file (это ошибка)

```sh
scope: 18/main
name: ubt-pg-aduron-dbnode1           # Изменить на 2 ноде

log:
  format: '%(asctime)s %(levelname)s: %(message)s'
  level: INFO
  max_queue_size: 1000
  traceback_level: ERROR
  type: plain
  dir: /mnt/data/log/patroni          # Добавлен
  file_size: 50000000                 # Добавлен
  file_num: 10                        # Добавлен

restapi:
  connect_address: 192.168.56.10:8008 # Изменить на 2 ноде
  listen: 192.168.56.10:8008          # Изменить на 2 ноде
  verify_client: optional             # Добавлен
  cafile: /opt/patroni/.tls/ca.crt    # Добавлен
  certfile: /opt/patroni/.tls/ubt-pg-aduron-dbnode1.crt # Изменить сертификаты на 2 ноде
  keyfile: /opt/patroni/.tls/ubt-pg-aduron-dbnode1.key  # Изменить ключ на 2 ноде
ctl:
  cacert: /opt/patroni/.tls/ca.crt    # Изменить сертификаты на 2 ноде
  certfile: /opt/patroni/.tls/ubt-pg-aduron-dbnode1.crt
  keyfile: /opt/patroni/.tls/ubt-pg-aduron-dbnode1.key
etcd3:
  hosts: ["ubt-pg-aduron-etcd1:2379", "ubt-pg-aduron-etcd2:2379", "ubt-pg-aduron-etcd3:2379"]
  protocol: https
  cacert: /opt/patroni/.tls/ca.crt
  cert: /opt/patroni/.tls/ubt-pg-aduron-dbnode1.crt # Изменить сертификаты на 2 ноде
  key: /opt/patroni/.tls/ubt-pg-aduron-dbnode1.key  # Изменить ключ на 2 ноде
watchdog:
  mode: off
  
# The bootstrap configuration. Works only when the cluster is not yet initialized.
# If the cluster is already initialized, all changes in the `bootstrap` section are ignored!
bootstrap:
  # This section will be written into <dcs>:/<namespace>/<scope>/config after initializing
  # new cluster and all other cluster members will use it as a `global configuration`.
  # WARNING! If you want to change any of the parameters that were set up
  # via `bootstrap.dcs` section, please use `patronictl edit-config`!
  dcs:
    failsafe_mode: true               # Добавлен
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576  # Добавлен
    synchronous_mode: true            # Добавлен
    synchronous_mode_strict: true     # Добавлен
    synchronous_mode_count: 1         # Добавлен
    master_start_timeout: 30          # Добавлен
    slots:
      prod_replica1:
        type: physical                # Добавлен
    postgresql:
      parameters:
        DateStyle: ISO, MDY
        TimeZone: Etc/UTC
        autovacuum_worker_slots: '16'
        default_text_search_config: pg_catalog.english
        dynamic_shared_memory_type: posix
        external_pid_file: /var/run/postgresql/18-main.pid
        hot_standby: 'on'
        lc_messages: en_US.UTF-8
        lc_monetary: en_US.UTF-8
        lc_numeric: en_US.UTF-8
        lc_time: en_US.UTF-8
        log_line_prefix: '%m [%p] %q%u@%d '
        log_timezone: Etc/UTC
        max_connections: '100'
        max_locks_per_transaction: '64'
        max_prepared_transactions: '0'
        max_replication_slots: '10'
        max_wal_senders: '10'
        max_wal_size: 1GB
        max_worker_processes: '8'
        min_wal_size: 80MB
        shared_buffers: 128MB
        ssl: 'on'
        ssl_cert_file: /etc/ssl/certs/ssl-cert-snakeoil.pem
        ssl_key_file: /etc/ssl/private/ssl-cert-snakeoil.key
        track_commit_timestamp: 'off'
        unix_socket_directories: /var/run/postgresql
        wal_keep_size: '0'
        wal_level: replica
        wal_log_hints: 'off'
      use_slots: true
      use_pg_rewind: true             # Добавлен
  pg_hba:
    - local all all peer
    - host all all 127.0.0.1/32 scram-sha-256
    - host all all 0.0.0.0/0 md5
    - host replication replicator 127.0.0.1/32 scram-sha-256        # Добавлен
    - host replication replicator 192.168.56.0/24 scram-sha-256     # Добавлен
  initdb: ["encoding=UTF8", "data-checksums", "username=postgres", "auth=scram-sha-256"]
  users:
    aduron:                           # Добавлен
      password: OracleDBA123
      options: ["createdb"]
	  
postgresql:                           # Добавлен
  authentication:
    replication:                      # Добавлен (Учетка для репликации)
      password: Replication123
      username: replicator
    superuser:                        # Добавлен (Учетка superuser)
      password: Oracle123
      username: postgres
  bin_dir: /usr/lib/postgresql/18/bin
  connect_address: 192.168.56.10:5432 # Изменить на 2 ноде
  data_dir: /mnt/data/postgresql/18/main
  listen: localhost:5432              # Добавлен
  parameters:
    config_file: /etc/postgresql/18/main/postgresql.conf    # Добавлен
    hba_file: /etc/postgresql/18/main/pg_hba.conf           # Добавлен
    ident_file: /etc/postgresql/18/main/pg_ident.conf       # Добавлен
  create_replica_methods: ["basebackup"]
  basebackup:
    max-rate: 100M
    checkpoint: fast

tags:
  clonefrom: true
  failover_priority: 1
  noloadbalance: false
  nostream: false
  nosync: false                 # Удалим после validate
  sync_priority: 1(patroni) 
```

Создадим папку для логирования
```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ mkdir -p /mnt/data/log/patroni
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ mkdir -p /mnt/data/log/patroni
```

> [!TIP]
> Проверить файл можно с помощью `patroni --validate-config /etc/patroni/config.yml`. В данном случае, это показывает что нам нужно
> - отключить сервис `postgresql` которого мы запустили для создании файла
> - выбрать между вариантами ('nosync', 'sync_priority')

```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patroni --validate-config /etc/patroni/config.yml
postgresql.listen localhost:5432 didn't pass validation: Port 5432 is already in use.
tags  Multiple of ('nosync', 'sync_priority') provided
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ systemctl stop postgresql@18-main
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ====
Authentication is required to stop 'postgresql@18-main.service'.
Authenticating as: Alain Duron (aduron)
Password:
==== AUTHENTICATION COMPLETE ====

# Удалим nosync
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ vi /etc/patroni/config.yml
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patroni --validate-config /etc/patroni/config.yml
```


#### Создание службы Patroni

Для автоматичново запуска вместо Postgresql, требуется создание нового сервиса Patroni который запустит сам постгрес. С этой целью создадим (на каждом ноде) следующий *unit-file*
```sh
aduron@ubt-pg-aduron-dbnode2:~$ sudo su - root
[sudo] password for aduron:
root@ubt-pg-aduron-dbnode2:~# vi /etc/systemd/system/patroni.service
root@ubt-pg-aduron-dbnode2:~# cat /etc/systemd/system/patroni.service
[Unit]
Description=Patroni high-availability PostgreSQL
After=network.target

[Service]
User=postgres
Type=simple
ExecStart=/opt/patroni/bin/patroni /etc/patroni/config.yml
Restart=always
RestartSec=5
LimitNOFILE=1024

[Install]
WantedBy=multi-user.target

root@ubt-pg-aduron-dbnode2:~# sudo systemctl daemon-reload
root@ubt-pg-aduron-dbnode2:~# sudo systemctl enable patroni
Created symlink /etc/systemd/system/multi-user.target.wants/patroni.service → /etc/systemd/system/patroni.service.
```


#### Запуск Patroni

Запускаем службу Patroni 
```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ systemctl start patroni
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ systemctl start patroni
```

И сразу в логе встечаем следуючее, бесконечно повторяющееся сообшение:
```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ cat /mnt/data/log/patroni/patroni.log
2026-01-16 21:48:01,737 ERROR: Failed to get list of machines from https://ubt-pg-aduron-etcd1:2379/v3: <Unknown error: '404 page not found', code: 2>
2026-01-16 21:48:01,767 ERROR: Failed to get list of machines from https://ubt-pg-aduron-etcd2:2379/v3: <Unknown error: '404 page not found', code: 2>
2026-01-16 21:48:01,796 ERROR: Failed to get list of machines from https://ubt-pg-aduron-etcd3:2379/v3: <Unknown error: '404 page not found', code: 2>
2026-01-16 21:48:01,796 INFO: waiting on etcd
2026-01-16 21:48:06,873 ERROR: Failed to get list of machines from https://ubt-pg-aduron-etcd1:2379/v3: <Unknown error: '404 page not found', code: 2>
2026-01-16 21:48:06,915 ERROR: Failed to get list of machines from https://ubt-pg-aduron-etcd2:2379/v3: <Unknown error: '404 page not found', code: 2>
2026-01-16 21:48:06,943 ERROR: Failed to get list of machines from https://ubt-pg-aduron-etcd3:2379/v3: <Unknown error: '404 page not found', code: 2>
2026-01-16 21:48:06,944 INFO: waiting on etcd
```

После некоторого времени посика, причину обнаружил [здесь](https://github.com/patroni/patroni/issues/1939?ysclid=mkhyncy9h3169799328) и [здесь](https://github.com/etcd-io/etcd/issues/12093).
Для взаймодействия между etcd и Patroni необходимо включить `enable-grpc-gateway: true` в etcd, иначе API-V3 может остаться недоступным. На наждом ноде В */etc/default/etcd/ubt-pg-aduron-etcdX.conf.yml* добавим:

```sh
enable-grpc-gateway: true
```

После этого перезапускаем службу *etcd*. И сразу в логах Patroni появляются новые сообшение касательно постгреса. Прогресс есть.
```sh
2026-01-17 06:44:11,826 ERROR: Failed to get list of machines from https://ubt-pg-aduron-etcd1:2379/v3: <Unknown error: '404 page not found', code: 2>
2026-01-17 06:44:11,827 INFO: waiting on etcd
2026-01-17 07:23:08,827 INFO: Selected new etcd server https://ubt-pg-aduron-etcd3:2379
2026-01-17 07:23:08,880 WARNING: postgresql parameter wal_keep_size=0 failed validation, defaulting to 128MB
2026-01-17 07:23:08,881 INFO: No PostgreSQL configuration items changed, nothing to reload.
2026-01-17 07:23:08,902 INFO: establishing a new patroni heartbeat connection to postgres
2026-01-17 07:23:09,218 INFO: establishing a new patroni heartbeat connection to postgres
2026-01-17 07:23:10,173 INFO: establishing a new patroni heartbeat connection to postgres
2026-01-17 07:23:11,204 INFO: establishing a new patroni heartbeat connection to postgres
2026-01-17 07:23:12,213 INFO: establishing a new patroni heartbeat connection to postgres
2026-01-17 07:23:12,236 WARNING: Retry got exception: connection problems
```

#### Решение проблем интеграции Постгреса в Patroni

В этом разделе описан ряд проблем с их решениями. Они могут случиться в любом порядке, в зависимости от настроек постргеса, patroni, ВМ и т.д.

##### FileNotFoundError: [Errno 2] (postgresql.conf)

```sh
2026-01-17 07:26:17,662 ERROR: Exception during execution of long running task restarting after failure
Traceback (most recent call last):
  File "/opt/patroni/lib/python3.12/site-packages/patroni/async_executor.py", line 166, in run
    wakeup = func(*args) if args else func()
             ^^^^^^^^^^^
  File "/opt/patroni/lib/python3.12/site-packages/patroni/postgresql/__init__.py", line 1175, in follow
    ret = self.start(timeout=timeout, block_callbacks=change_role, role=role) or None
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/patroni/lib/python3.12/site-packages/patroni/postgresql/__init__.py", line 778, in start
    self.config.write_postgresql_conf(configuration)
  File "/opt/patroni/lib/python3.12/site-packages/patroni/postgresql/config.py", line 544, in write_postgresql_conf
    os.rename(self._postgresql_conf, self._postgresql_base_conf)
FileNotFoundError: [Errno 2] No such file or directory: '/mnt/data/postgresql/18/main/postgresql.conf' -> '/mnt/data/postgresql/18/main/postgresql.base.conf'
```

Как описано в [документации](https://patroni.readthedocs.io/en/latest/patroni_configuration.html), при запуске Patroni ишет файлы настроек в определенном порядке. 

> [!TIP]
> Достаточно создать файл таким образом:
> `touch /mnt/data/postgresql/18/main/postgresql.conf`

После создания, Конфигурация переливается в этот файл и постгрес запускается

```sh
2026-01-17 07:36:40,930 INFO: Lock owner: None; I am ubt-pg-aduron-dbnode2
2026-01-17 07:36:40,930 INFO: starting as a secondary
2026-01-17 07:36:41,493 INFO: postmaster pid=35693
2026-01-17 07:36:41,536 INFO: establishing a new patroni heartbeat connection to postgres
```

##### INFO: Error communicating with PostgreSQL. Will try again later / WARNING: Failed to determine PostgreSQL state from the connection

Patroni не может подключиться к Постгресу
```sh
2026-01-17 07:55:29,851 INFO: Error communicating with PostgreSQL. Will try again later
2026-01-17 07:55:38,949 INFO: establishing a new patroni heartbeat connection to postgres
2026-01-17 07:55:39,723 INFO: establishing a new patroni heartbeat connection to postgres
2026-01-17 07:55:39,756 WARNING: Retry got exception: connection problems
2026-01-17 07:55:39,771 WARNING: Failed to determine PostgreSQL state from the connection, falling back to cached role
```
Также бывает, что невозможно подключиться с паролем:
```sh
2026-01-17 07:52:19.572 UTC [36518] postgres@postgres FATAL:  password authentication failed for user "postgres"
2026-01-17 07:52:19.572 UTC [36518] postgres@postgres DETAIL:  User "postgres" has no password assigned.
        Connection matched file "/etc/postgresql/18/main/pg_hba.conf" line 125: "host    all             all             127.0.0.1/32            scram-sha-256"
```

> [!TIP]
> Здесь необходимо проверить, что учетки, описаны в конфиге, существуют с верными паролями

```sh
postgres=# alter user postgres password 'Oracle123';
ALTER ROLE
postgres=# create user replicator password 'Replication123';
CREATE ROLE
postgres=# alter user replicator replication;
ALTER ROLE
postgres=# create user aduron password 'OracleDBA123' Superuser createdb;
CREATE ROLE
postgres=# \du
                              List of roles
 Role name  |                         Attributes
------------+------------------------------------------------------------
 aduron     | Superuser, Create DB
 postgres   | Superuser, Create role, Create DB, Replication, Bypass RLS
 replicator | Replication
```

##### Проблемы с файлом pg_hba.conf

Вспомним, что мы указали следущий раздел 
```sh
  parameters:
    config_file: /etc/postgresql/18/main/postgresql.conf    # Добавлен
    hba_file: /etc/postgresql/18/main/pg_hba.conf           # Добавлен
    ident_file: /etc/postgresql/18/main/pg_ident.conf       # Добавлен
```
Однако при попытке изменить, напимер `/etc/postgresql/18/main/pg_hba.conf`, постгрес не принимает эти изменения. Например, добавляем:
```
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml edit-config
---
+++
@@ -45,7 +45,6 @@
   - host all postgres 192.168.56.10/24 scram-sha-256
   - host replication replicator 192.168.56.20/24 scram-sha-256
   - host all postgres 192.168.56.20/24 scram-sha-256
-  - host all all 192.168.47.10/24 scram-sha-256
+  - host replication replicator 192.168.56.10/24 scram-sha-256
+  - host all postgres 192.168.56.10/24 scram-sha-256
+  - host replication replicator 192.168.56.20/24 scram-sha-256
+  - host all postgres 192.168.56.20/24 scram-sha-256
  initdb: ["encoding=UTF8", "data-checksums", "username=postgres", "auth=scram-sha-256"]
```

> [!TIP]
> В связи с тем, что указали значение *hba_file*, Patroni игнорирует дунамическую конфигурацию в разделе *pg_hba*. 
> Здесь удалил польностю настройки `config_file`,`hba_file`,`ident_file` чтобы patroni использовал применял только дунамическую конфигурацию.


##### Применение listen_adresses

Наверняка настройка, на которой я потратил найбольще времени. Дела в том, что изменить ее можно, например, следующим способом

```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml edit-config 18/main --set listen_addresses="localhost,192.168.56.20,192.168.56.10,192.168.56.30" --force
---
+++
@@ -1,5 +1,5 @@
 failsafe_mode: true
-listen_addresses: localhost,192.168.56.20,192.168.56.10
+listen_addresses: localhost,192.168.56.20,192.168.56.10,192.168.56.30
 loop_wait: 10
 master_start_timeout: 30
 maximum_lag_on_failover: 1048576

Configuration changed


(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml restart 18/main ubt-pg-aduron-dbnode2
+ Cluster: 18/main (7590773680200294160) ---------+---------+----+-------------+-----+------------+-----+-----------------+----------------------------------+----------------------+
| Member                | Host          | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Pending restart | Pending restart reason           | Tags                 |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+-----------------+----------------------------------+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Replica | running |  1 |   0/1000000 |   8 |  0/17AF040 |   0 | *               | config_file: [hidden - too long] | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     |                 |                                  | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     |                 |                                  | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+-----------------+----------------------------------+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader  | running |  6 |             |     |            |     | *               | config_file: [hidden - too long] | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     |                 |                                  | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     |                 |                                  | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+-----------------+----------------------------------+----------------------+
When should the restart take place (e.g. 2026-01-18T09:11)  [now]:
Are you sure you want to restart members ubt-pg-aduron-dbnode2? [y/N]: y
Restart if the PostgreSQL version is less than provided (e.g. 9.5.2)  []:
Success: restart on member ubt-pg-aduron-dbnode2
```

patronictl этого позволит, однако после перезапуска, постгрес всё же ее не применяет:
```sh
postgres=# show listen_addresses;
 listen_addresses
------------------
 localhost
(1 row)
```

В конце концов, верный способ этого настроить нашелся в документации:

<img src="img/3_patroni/listen_addresses.png" width="700" />

> [!TIP]
> Другими словами, это означает что нужно:
> - Убрать настойку `listen_addresses` из конфига.
> - Вместе него пользоваться параметром `listen`, который как раз был настроен на 'localhost'. Поставим '0.0.0.0'.
> 
> Затем сделал `reload`, `restart` мастера и `restart` реплики. 

Наконец-то listen_addresses принимает верное значение и позволяет подключаться...
```sh
postgres=# show listen_addresses
postgres-# ;
 listen_addresses
------------------
 0.0.0.0
(1 row)

aduron@ubt-pg-aduron-dbnode1:~$ psql -h 192.168.56.20 -p 5432 -U postgres
Password for user postgres:
psql (18.1 (Ubuntu 18.1-1.pgdg24.04+2))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

postgres=#

aduron@ubt-pg-aduron-dbnode1:~$ psql -h 192.168.56.10 -p 5432 -U postgres
Password for user postgres:
psql (18.1 (Ubuntu 18.1-1.pgdg24.04+2))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

postgres=#
```
... что в свой очерень допускает синхронизацию реплики с мастера.
```sh
Jan 18 08:36:26 ubt-pg-aduron-dbnode1 patroni[4454]: 2026-01-18 08:36:26.112 UTC [4454] LOG:  started streaming WAL from primary at 0/1000000 on timeline 6
Jan 18 08:36:27 ubt-pg-aduron-dbnode1 patroni[4451]: 2026-01-18 08:36:27.970 UTC [4451] LOG:  redo starts at 0/17B0440

Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2103]: 2026-01-18 08:36:27.959 UTC [2103] replicator@[unknown] LOG:  standby "ubt-pg-aduron-dbnode1" is now a synchronous standby with priority 1
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2103]: 2026-01-18 08:36:27.959 UTC [2103] replicator@[unknown] STATEMENT:  START_REPLICATION SLOT "ubt_pg_aduron_dbnode1" 0/1000000 TIMELINE 6
```



#### Состояние кластера в конце этого шага

У нас работоспособный кластер с точки зрения репликации на базе *Patroni* и *etcd*
- *Patroni* правилно запускает участников кластера, управляет ими и их конфигурацией. Та конфигурация правильно сохраняеться в DCS и применяется.
- Состояние верное в зависимости от настроек репликации.
- *Patroni* сам же инициализировал *replica* до правильного состояния.
- Службы правильно настроены, как с стороны *etcd*, как и со стороны *Postgres* / *Patroni*.  

```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Sync Standby | streaming |  6 |   0/17B05A8 |   0 |  0/17B05A8 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader       | running   |  6 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+

aduron@ubt-pg-aduron-dbnode2:~$ sudo systemctl status patroni.service
[sudo] password for aduron:
● patroni.service - Patroni high-availability PostgreSQL
     Loaded: loaded (/etc/systemd/system/patroni.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-01-18 06:57:34 UTC; 2h 26min ago
   Main PID: 783 (patroni)
      Tasks: 18 (limit: 2265)
     Memory: 281.1M (peak: 306.9M)
        CPU: 23.006s
     CGroup: /system.slice/patroni.service
             ├─ 783 /opt/patroni/bin/python3 /opt/patroni/bin/patroni /etc/patroni/config.yml
             ├─2083 /usr/lib/postgresql/18/bin/postgres -D /mnt/data/postgresql/18/main --config-file=/mnt/data/postgresql/18/main/postgresql.conf --listen_addresses=0.0.0.0 --port=5432 --cluster_name=18/m>
             ├─2084 "postgres: 18/main: io worker 0"
             ├─2085 "postgres: 18/main: io worker 1"
             ├─2086 "postgres: 18/main: io worker 2"
             ├─2087 "postgres: 18/main: checkpointer "
             ├─2088 "postgres: 18/main: background writer "
             ├─2091 "postgres: 18/main: walwriter "
             ├─2092 "postgres: 18/main: autovacuum launcher "
             ├─2093 "postgres: 18/main: logical replication launcher "
             ├─2097 "postgres: 18/main: postgres postgres 127.0.0.1(45512) idle"
             └─2103 "postgres: 18/main: walsender replicator 192.168.56.10(59640) streaming 0/17B05A8"

Jan 18 08:36:17 ubt-pg-aduron-dbnode2 patroni[2095]: localhost:5432 - accepting connections
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2104]: server signaled
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2083]: 2026-01-18 08:36:27.806 UTC [2083] LOG:  received SIGHUP, reloading configuration files
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2083]: 2026-01-18 08:36:27.806 UTC [2083] LOG:  parameter "synchronous_standby_names" changed to ""ubt-pg-aduron-dbnode1""
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2083]: 2026-01-18 08:36:27.808 UTC [2083] LOG:  could not open file "/mnt/data/postgresql/18/main/pg_ident.conf": No such file or directory
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2083]: 2026-01-18 08:36:27.808 UTC [2083] LOG:  /mnt/data/postgresql/18/main/pg_ident.conf was not reloaded
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2103]: 2026-01-18 08:36:27.959 UTC [2103] replicator@[unknown] LOG:  standby "ubt-pg-aduron-dbnode1" is now a synchronous standby with priority 1
Jan 18 08:36:27 ubt-pg-aduron-dbnode2 patroni[2103]: 2026-01-18 08:36:27.959 UTC [2103] replicator@[unknown] STATEMENT:  START_REPLICATION SLOT "ubt_pg_aduron_dbnode1" 0/1000000 TIMELINE 6
Jan 18 08:41:17 ubt-pg-aduron-dbnode2 patroni[2087]: 2026-01-18 08:41:17.918 UTC [2087] LOG:  checkpoint starting: time
Jan 18 08:41:17 ubt-pg-aduron-dbnode2 patroni[2087]: 2026-01-18 08:41:17.963 UTC [2087] LOG:  checkpoint complete: wrote 0 buffers (0.0%), wrote 3 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; 


aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl status patroni.service
● patroni.service - Patroni high-availability PostgreSQL
     Loaded: loaded (/etc/systemd/system/patroni.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-01-18 06:57:31 UTC; 2h 26min ago
   Main PID: 775 (patroni)
      Tasks: 16 (limit: 2265)
     Memory: 191.6M (peak: 212.6M)
        CPU: 47.999s
     CGroup: /system.slice/patroni.service
             ├─ 775 /opt/patroni/bin/python3 /opt/patroni/bin/patroni /etc/patroni/config.yml
             ├─4445 /usr/lib/postgresql/18/bin/postgres -D /mnt/data/postgresql/18/main --config-file=/mnt/data/postgresql/18/main/postgresql.conf --listen_addresses=0.0.0.0 --port=5432 --cluster_name=18/m>
             ├─4446 "postgres: 18/main: io worker 0"
             ├─4447 "postgres: 18/main: io worker 1"
             ├─4448 "postgres: 18/main: io worker 2"
             ├─4449 "postgres: 18/main: checkpointer "
             ├─4450 "postgres: 18/main: background writer "
             ├─4451 "postgres: 18/main: startup recovering 000000060000000000000001"
             ├─4454 "postgres: 18/main: walreceiver streaming 0/17B05A8"
             └─4457 "postgres: 18/main: postgres postgres 127.0.0.1(38540) idle"

Jan 18 08:36:26 ubt-pg-aduron-dbnode1 patroni[4445]: 2026-01-18 08:36:26.084 UTC [4445] LOG:  database system is ready to accept read-only connections
Jan 18 08:36:26 ubt-pg-aduron-dbnode1 patroni[4453]: 2026-01-18 08:36:26.087 UTC [4453] postgres@postgres FATAL:  the database system is starting up
Jan 18 08:36:26 ubt-pg-aduron-dbnode1 patroni[4452]: localhost:5432 - rejecting connections
Jan 18 08:36:26 ubt-pg-aduron-dbnode1 patroni[4455]: localhost:5432 - accepting connections
Jan 18 08:36:26 ubt-pg-aduron-dbnode1 patroni[4454]: 2026-01-18 08:36:26.112 UTC [4454] LOG:  started streaming WAL from primary at 0/1000000 on timeline 6
Jan 18 08:36:27 ubt-pg-aduron-dbnode1 patroni[4451]: 2026-01-18 08:36:27.970 UTC [4451] LOG:  redo starts at 0/17B0440
Jan 18 08:41:26 ubt-pg-aduron-dbnode1 patroni[4449]: 2026-01-18 08:41:26.202 UTC [4449] LOG:  restartpoint starting: time
Jan 18 08:41:26 ubt-pg-aduron-dbnode1 patroni[4449]: 2026-01-18 08:41:26.235 UTC [4449] LOG:  restartpoint complete: wrote 0 buffers (0.0%), wrote 2 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled>
Jan 18 08:41:26 ubt-pg-aduron-dbnode1 patroni[4449]: 2026-01-18 08:41:26.235 UTC [4449] LOG:  recovery restart point at 0/17B04A0
Jan 18 08:41:26 ubt-pg-aduron-dbnode1 patroni[4449]: 2026-01-18 08:41:26.235 UTC [4449] DETAIL:  Last completed transaction was at log time 2026-01-18 08:36:27.956562+00.
```


### Тестирование переключения и отказоустойчивости кластера

#### Pause / Resume (Отключение управления кластером в планированных ситуации)

Перед тем, как стопнуть все наши ВМ, поставим кластер Patroni на паузу. Это означает, что Patroni Больше не пример решений управления кластером, что позводяет выполнить планированные задачи (апгрейд, отключение нодов...). В этом проекте пользуемся этой коммандой, чтобы состояние кластера не менялось, особенно кодка ВМ отключаем. 

```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml pause 18/main
Success: cluster management is paused
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) ---------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Replica | running |  6 |     unknown |     |  0/17B05A8 |   0 | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Replica | stopped |    |     unknown |     |    unknown |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
 Maintenance mode: on
```

После завершения нужных операций, можно перезапустить управление с коммандой `resume`, таким способом

```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml resume 18/main
Success: cluster management is resumed
```

Однако в данном случае, что-то пошло не по плану, и кластер остался в непонятном состоянии
- Лидер видимо нормально запустился (TL 7)
- Реплика осталась на уровень TL 6 с непонятними сообщениями *patroni[xxx]: server signaled*
```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) ---------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Replica | running |  6 |     unknown |     |  0/17B05A8 |   0 | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader  | running |  7 |             |     |            |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+

aduron@ubt-pg-aduron-dbnode1:~$ journalctl -feu patroni
Jan 23 17:35:08 ubt-pg-aduron-dbnode1 systemd[1]: Started patroni.service - Patroni high-availability PostgreSQL.
Jan 23 17:35:10 ubt-pg-aduron-dbnode1 patroni[801]: postgresql parameter listen_addresses=localhost,192.168.56.20,192.168.56.10 failed validation, defaulting to None
Jan 23 17:35:10 ubt-pg-aduron-dbnode1 patroni[801]: postgresql parameter wal_keep_size=0 failed validation, defaulting to 128MB
Jan 23 17:35:12 ubt-pg-aduron-dbnode1 patroni[914]: localhost:5432 - accepting connections
Jan 23 17:35:12 ubt-pg-aduron-dbnode1 patroni[917]: server signaled
Jan 23 17:37:48 ubt-pg-aduron-dbnode1 patroni[1187]: server signaled
Jan 23 17:37:50 ubt-pg-aduron-dbnode1 patroni[1189]: server signaled
Jan 23 17:37:51 ubt-pg-aduron-dbnode1 patroni[1194]: server signaled
```

Сравнение между нодами в кнце концов показало, что я неправильно отключил службу Postgresql на пердом ноде

```sh
aduron@ubt-pg-aduron-dbnode2:~$ sudo systemctl status postgresql.service
[sudo] password for aduron:
○ postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; disabled; preset: enabled)
     Active: inactive (dead)

Last login: Fri Jan 23 19:20:32 2026 from 192.168.56.1
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl status postgresql.service
[sudo] password for aduron:
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; enabled; preset: enabled)
     Active: active (exited) since Fri 2026-01-23 19:19:30 UTC; 2min 4s ago
    Process: 882 ExecStart=/bin/true (code=exited, status=0/SUCCESS)
   Main PID: 882 (code=exited, status=0/SUCCESS)
        CPU: 1ms
```

Вот что предположительно случилось
- Сервис Постгреса был правильно отключен во время создание кластера (в начале проекта)
- С целью создать *config* Patroni, на первом ноде временно его включили, на первом ноде. Одноко забыл эго отключить после этого шага.
- После перезапуска ВМ, сервис Postgresql запускается (что видно и в консоле) и не допускает управления кластором с помощью Patroni

Решать эту проблему можно вот так
```sh
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl disable postgresql.service
Synchronizing state of postgresql.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install disable postgresql
Removed "/etc/systemd/system/multi-user.target.wants/postgresql.service".
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl daemon-reload
aduron@ubt-pg-aduron-dbnode1:~$ sudo systemctl status postgresql.service
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; disabled; preset: enabled)
     Active: active (exited) since Fri 2026-01-23 19:19:30 UTC; 2min 29s ago
   Main PID: 882 (code=exited, status=0/SUCCESS)
        CPU: 1ms

Jan 23 19:19:30 ubt-pg-aduron-dbnode1 systemd[1]: Starting postgresql.service - PostgreSQL RDBMS...
Jan 23 19:19:30 ubt-pg-aduron-dbnode1 systemd[1]: Finished postgresql.service - PostgreSQL RDBMS.
```


#### Switchover

Проверяем как именно делается switchover в Patroni

```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml switchover --help
Usage: patronictl switchover [OPTIONS] [CLUSTER_NAME]

  Switchover to a replica

Options:
  --group INTEGER           Citus group
  --leader, --primary TEXT  The name of the current leader
  --candidate TEXT          The name of the candidate
  --scheduled TEXT          Timestamp of a scheduled switchover in unambiguous
                            format (e.g. ISO 8601)
  --force                   Do not ask for confirmation at any point
  --help                    Show this message and exit.
```

Дальше:
```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml switchover --leader ubt-pg-aduron-dbnode2 --candidate ubt-pg-aduron-dbnode1 18/main
Current cluster topology
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Sync Standby | streaming |  7 |   0/17B09F8 |   0 |  0/17B09F8 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader       | running   |  7 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
When should the switchover take place (e.g. 2026-01-23T18:50 )  [now]:
Are you sure you want to switchover cluster 18/main, demoting current leader ubt-pg-aduron-dbnode2? [y/N]: y
2026-01-23 17:50:16.67020 Successfully switched over to "ubt-pg-aduron-dbnode1"
+ Cluster: 18/main (7590773680200294160) ---------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Leader  | running |  7 |             |     |            |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Replica | stopped |    |     unknown |     |    unknown |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
```
После несколько секунд, вотром ноде принимает роль *Sync Standby*
```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Leader       | running   |  8 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Sync Standby | streaming |  8 |   0/17B0D08 |   0 |  0/17B0D08 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
```

Обратное переключение 
```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml switchover --leader ubt-pg-aduron-dbnode1 --candidate ubt-pg-aduron-dbnode2 18/main
Current cluster topology
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Leader       | running   |  8 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Sync Standby | streaming |  8 |   0/17B0E10 |   0 |  0/17B0E10 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
When should the switchover take place (e.g. 2026-01-23T19:24 )  [now]:
Are you sure you want to switchover cluster 18/main, demoting current leader ubt-pg-aduron-dbnode1? [y/N]: y
2026-01-23 18:24:21.44745 Successfully switched over to "ubt-pg-aduron-dbnode2"
+ Cluster: 18/main (7590773680200294160) ---------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Replica | stopped |    |     unknown |     |    unknown |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader  | running |  8 |             |     |            |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Sync Standby | streaming |  9 |   0/17B10C0 |   0 |  0/17B10C0 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader       | running   |  9 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
```

#### Потерь реплики *ubt-pg-aduron-dbnode1*

При отключении реплики, замечается что Patroni потеряет соединение с точки *etcd* ubt-pg-aduron-etcd1.
```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml list 18/main
2026-01-23 18:40:22,104 - ERROR - Failed to get list of machines from https://ubt-pg-aduron-etcd1:2379/v3beta: MaxRetryError('HTTPSConnectionPool(host=\'ubt-pg-aduron-etcd1\', port=2379): Max retries exceeded with url: /version (Caused by NewConnectionError("HTTPSConnection(host=\'ubt-pg-aduron-etcd1\', port=2379): Failed to establish a new connection: [Errno 111] Connection refused"))')
+ Cluster: 18/main (7590773680200294160) ---------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role    | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+---------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Replica | streaming |  9 |   0/17B13F0 |   0 |  0/17B13F0 |   0 | clonefrom: true      |
|                       |               |         |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |           |    |             |     |            |     | nosync: true         |
|                       |               |         |           |    |             |     |            |     | sync_priority: 0     |
+-----------------------+---------------+---------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader  | running   |  9 |             |     |            |     | clonefrom: true      |
|                       |               |         |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+-----------+----+-------------+-----+------------+-----+----------------------+
(patroni) postgres@ubt-pg-aduron-dbnode2:~$
```
После 30 секунд Patroni считает, что можно вытеснить этого участника из кластера.
```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) --------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role   | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader | running |  9 |             |     |            |     | clonefrom: true      |
|                       |               |        |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |        |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------+---------+----+-------------+-----+------------+-----+----------------------+
```

После перезапуска, он возврашается в состав кдастера etcd
```sh
Jan 23 18:43:35 ubt-pg-aduron-dbnode2 etcd[763]: failed to reach the peerURL(https://ubt-pg-aduron-etcd1:2380) of member 75ae20a713d9d171 (Get "https://ubt-pg-aduron-etcd1:2380/version": dial tcp 192.168.47.10:2380: connect: connection refused)
Jan 23 18:43:35 ubt-pg-aduron-dbnode2 etcd[763]: cannot get the version of member 75ae20a713d9d171 (Get "https://ubt-pg-aduron-etcd1:2380/version": dial tcp 192.168.47.10:2380: connect: connection refused)
Jan 23 18:43:36 ubt-pg-aduron-dbnode2 etcd[763]: peer 75ae20a713d9d171 became active
Jan 23 18:43:36 ubt-pg-aduron-dbnode2 etcd[763]: established a TCP streaming connection with peer 75ae20a713d9d171 (stream MsgApp v2 reader)
Jan 23 18:43:36 ubt-pg-aduron-dbnode2 etcd[763]: established a TCP streaming connection with peer 75ae20a713d9d171 (stream Message reader)
Jan 23 18:43:36 ubt-pg-aduron-dbnode2 etcd[763]: established a TCP streaming connection with peer 75ae20a713d9d171 (stream MsgApp v2 writer)
Jan 23 18:43:36 ubt-pg-aduron-dbnode2 etcd[763]: established a TCP streaming connection with peer 75ae20a713d9d171 (stream Message writer)
Jan 23 18:43:40 ubt-pg-aduron-dbnode2 etcd[763]: the clock difference against peer 75ae20a713d9d171 is too high [2.232529576s > 1s]
Jan 23 18:43:40 ubt-pg-aduron-dbnode2 etcd[763]: the clock difference against peer 75ae20a713d9d171 is too high [2.250913217s > 1s]
```
и также в состав кластера Patroni
```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Sync Standby | streaming |  9 |   0/17B1558 |   0 |  0/17B1558 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader       | running   |  9 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+

Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1246]: 2026-01-23 18:46:15.812 GMT [1246] LOG:  starting PostgreSQL 18.1 (Ubuntu 18.1-1.pgdg24.04+2) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0, 64-bit
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1246]: 2026-01-23 18:46:15.813 GMT [1246] LOG:  listening on IPv4 address "0.0.0.0", port 5432
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1246]: 2026-01-23 18:46:15.816 GMT [1246] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:46:15.826 GMT [1252] LOG:  database system was shut down in recovery at 2026-01-23 18:46:15 GMT
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:46:15.827 GMT [1252] LOG:  entering standby mode
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1254]: 2026-01-23 18:46:15.833 GMT [1254] FATAL:  the database system is starting up
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1253]: localhost:5432 - rejecting connections
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:46:15.845 GMT [1252] LOG:  redo starts at 0/17B12E8
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:46:15.845 GMT [1252] LOG:  consistent recovery state reached at 0/17B13F0
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:46:15.845 GMT [1252] LOG:  invalid record length at 0/17B13F0: expected at least 24, got 0
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1246]: 2026-01-23 18:46:15.845 GMT [1246] LOG:  database system is ready to accept read-only connections
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1256]: 2026-01-23 18:46:15.846 GMT [1256] FATAL:  the database system is starting up
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1255]: localhost:5432 - rejecting connections
Jan 23 18:46:15 ubt-pg-aduron-dbnode1 patroni[1257]: 2026-01-23 18:46:15.872 GMT [1257] LOG:  started streaming WAL from primary at 0/1000000 on timeline 9
Jan 23 18:46:16 ubt-pg-aduron-dbnode1 patroni[1258]: localhost:5432 - accepting connections
```

#### Failover - Потерь мастера *ubt-pg-aduron-dbnode2*

В этот раз отключаем текущего мастера ubt-pg-aduron-dbnode2. Это сразу замеячается на стендбай (*[1353] FATAL:  streaming replication receiver "18/main" could not connect to the primary server*). После несколько секунд Patroni выполняет комманду *Promote* в постгресе.

```sh
Jan 23 18:52:05 ubt-pg-aduron-dbnode1 patroni[1257]: 2026-01-23 18:52:05.725 GMT [1257] FATAL:  could not receive data from WAL stream: FATAL:  terminating connection due to administrator command
Jan 23 18:52:05 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:05.728 GMT [1252] LOG:  invalid record length at 0/17B16C0: expected at least 24, got 0
Jan 23 18:52:05 ubt-pg-aduron-dbnode1 patroni[1353]: 2026-01-23 18:52:05.802 GMT [1353] FATAL:  streaming replication receiver "18/main" could not connect to the primary server: connection to server at "192.168.56.20", port 5432 failed: FATAL:  the database system is shutting down
Jan 23 18:52:05 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:05.802 GMT [1252] LOG:  waiting for WAL to become available at 0/17B16D8
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1358]: server signaled
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1246]: 2026-01-23 18:52:07.222 GMT [1246] LOG:  received SIGHUP, reloading configuration files
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1246]: 2026-01-23 18:52:07.223 GMT [1246] LOG:  parameter "synchronous_standby_names" changed to "*"
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1360]: 2026-01-23 18:52:07.229 GMT [1360] FATAL:  streaming replication receiver "18/main" could not connect to the primary server: connection to server at "192.168.56.20", port 5432 failed: Connection refused
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1360]:                 Is the server running on that host and accepting TCP/IP connections?
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:07.229 GMT [1252] LOG:  waiting for WAL to become available at 0/17B16D8
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1361]: server promoting
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:07.318 GMT [1252] LOG:  received promote request
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:07.318 GMT [1252] LOG:  redo done at 0/17B1688 system usage: CPU: user: 0.00 s, system: 0.00 s, elapsed: 351.47 s
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:07.318 GMT [1252] LOG:  last completed transaction was at log time 2026-01-23 18:46:22.496364+00
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:07.326 GMT [1252] LOG:  selected new timeline ID: 10
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1252]: 2026-01-23 18:52:07.428 GMT [1252] LOG:  archive recovery complete
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1250]: 2026-01-23 18:52:07.440 GMT [1250] LOG:  checkpoint starting: force
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1246]: 2026-01-23 18:52:07.441 GMT [1246] LOG:  database system is ready to accept connections
Jan 23 18:52:07 ubt-pg-aduron-dbnode1 patroni[1250]: 2026-01-23 18:52:07.456 GMT [1250] LOG:  checkpoint complete: wrote 0 buffers (0.0%), wrote 2 SLRU buffers; 0 WAL file(s) added, 0 removed, 0 recycled; write=0.004 s, sync=0.002 s, total=0.017 s; sync files=2, longest=0.001 s, average=0.001 s; distance=0 kB, estimate=0 kB; lsn=0/17B1750, redo lsn=0/17B16F8
```
В patronictl *ubt-pg-aduron-dbnode1* принимает роль лидера. После 30 секунд отсутствия доступа *ubt-pg-aduron-dbnode2* вытесняется. 
```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) ---------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Leader  | running | 10 |             |     |            |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Replica | stopped |    |     unknown |     |    unknown |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+

(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml list 18/main
2026-01-23 18:52:40,352 - ERROR - Failed to get list of machines from https://ubt-pg-aduron-etcd2:2379/v3beta: MaxRetryError("HTTPSConnectionPool(host='ubt-pg-aduron-etcd2', port=2379): Max retries exceeded with url: /version (Caused by ConnectTimeoutError(<HTTPSConnection(host='ubt-pg-aduron-etcd2', port=2379) at 0x746a69df19d0>, 'Connection to ubt-pg-aduron-etcd2 timed out. (connect timeout=1.6666666666666667)'))")
+ Cluster: 18/main (7590773680200294160) --------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role   | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Leader | running | 10 |             |     |            |     | clonefrom: true      |
|                       |               |        |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |        |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------+---------+----+-------------+-----+------------+-----+----------------------+
(patroni) postgres@ubt-pg-aduron-dbnode1:~$
```

После перезапуска сервера, *ubt-pg-aduron-dbnode2* принимает роль *Standby* и синхронизируется
```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Leader       | running   | 10 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Sync Standby | streaming | 10 |   0/17B18C0 |   0 |  0/17B18C0 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
```


### Подключение с помощью HAProxy

#### Установление HAProxy

```sh
aduron@ubt-pg-aduron-cluster3:~$ sudo apt install haproxy
[sudo] password for aduron:
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages were automatically installed and are no longer required:
  dns-root-data dnsmasq-base libbluetooth3 libndp0 libnm0 libteamdctl0 ppp pptp-linux
Use 'sudo apt autoremove' to remove them.
The following additional packages will be installed:
  liblua5.4-0
Suggested packages:
  vim-haproxy haproxy-doc
The following NEW packages will be installed:
  haproxy liblua5.4-0
0 upgraded, 2 newly installed, 0 to remove and 2 not upgraded.
Need to get 2,236 kB of archives.
After this operation, 5,274 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://archive.ubuntu.com/ubuntu noble/main amd64 liblua5.4-0 amd64 5.4.6-3build2 [166 kB]
Get:2 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 haproxy amd64 2.8.16-0ubuntu0.24.04.1 [2,070 kB]
Fetched 2,236 kB in 2s (1,164 kB/s)
Selecting previously unselected package liblua5.4-0:amd64.
(Reading database ... 93677 files and directories currently installed.)
Preparing to unpack .../liblua5.4-0_5.4.6-3build2_amd64.deb ...
Unpacking liblua5.4-0:amd64 (5.4.6-3build2) ...
Selecting previously unselected package haproxy.
Preparing to unpack .../haproxy_2.8.16-0ubuntu0.24.04.1_amd64.deb ...
Unpacking haproxy (2.8.16-0ubuntu0.24.04.1) ...
Setting up liblua5.4-0:amd64 (5.4.6-3build2) ...
Setting up haproxy (2.8.16-0ubuntu0.24.04.1) ...
Created symlink /etc/systemd/system/multi-user.target.wants/haproxy.service → /usr/lib/systemd/system/haproxy.service.
Processing triggers for libc-bin (2.39-0ubuntu8.6) ...
Processing triggers for rsyslog (8.2312.0-3ubuntu9.1) ...
Processing triggers for man-db (2.12.0-4build2) ...
Scanning processes...
Scanning linux images...

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

aduron@ubt-pg-aduron-cluster3:~$ sudo mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.backup_26012026


> [!CAUTION]
> Порт *frontend* должен быть свободен, иначе появится подобнапя ошибка: 
> `cannot bind socket (Address already in use) for [0.0.0.0:5432]`
> В моем случае, это случилось из-за того, что кластер постгресса был ещё настроен на 3ем ноде после клонирования

```sh
Jan 26 18:23:24 ubt-pg-aduron-cluster3 haproxy[1539]: [NOTICE]   (1539) : haproxy version is 2.8.16-0ubuntu0.24.04.1
Jan 26 18:23:24 ubt-pg-aduron-cluster3 haproxy[1539]: [NOTICE]   (1539) : path to executable is /usr/sbin/haproxy
Jan 26 18:23:24 ubt-pg-aduron-cluster3 haproxy[1539]: [ALERT]    (1539) : Binding [/etc/haproxy/haproxy.cfg:39] for proxy postgres: cannot bind socket (Address already in use) for [0.0.0.0:5432]
Jan 26 18:23:24 ubt-pg-aduron-cluster3 haproxy[1539]: [ALERT]    (1539) : [/usr/sbin/haproxy.main()] Some protocols failed to start their listeners! Exiting.
Jan 26 18:23:24 ubt-pg-aduron-cluster3 systemd[1]: haproxy.service: Main process exited, code=exited, status=1/FAILURE
```
После отключения haproxy запустился без проблем
```sh
aduron@ubt-pg-aduron-cluster3:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
18  main    5432 online postgres /var/lib/postgresql/18/main /var/log/postgresql/postgresql-18-main.log
aduron@ubt-pg-aduron-cluster3:~$ sudo systemctl stop postgresql
aduron@ubt-pg-aduron-cluster3:~$ sudo pg_dropcluster 18 main
aduron@ubt-pg-aduron-cluster3:~$ sudo pg_lsclusters
Ver Cluster Port Status Owner Data directory Log file
```


#### Простая roundrobin конфигурация (без проверения ролей)

```sh
aduron@ubt-pg-aduron-cluster3:~$ sudo vi /etc/haproxy/haproxy.cfg
global
    daemon
    maxconn 4096
    log stdout local0
    stats socket /var/lib/haproxy/stats mode 660 level admin

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    log global

frontend postgres_ssl
    bind *:5432
    default_backend postgres_backend

backend postgres_backend
    balance roundrobin
    server ubt-pg-aduron-dbnode1 192.168.56.10:5432 check inter 5000ms rise 2 fall 3 on-marked-down shutdown-sessions
    server ubt-pg-aduron-dbnode2 192.168.56.20:5432 check inter 5000ms rise 2 fall 3 on-marked-down shutdown-sessions

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
```

```sh
aduron@ubt-pg-aduron-cluster3:~$ sudo systemctl status haproxy
● haproxy.service - HAProxy Load Balancer
     Loaded: loaded (/usr/lib/systemd/system/haproxy.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-01-26 18:44:18 UTC; 25s ago
       Docs: man:haproxy(1)
             file:/usr/share/doc/haproxy/configuration.txt.gz
   Main PID: 2018 (haproxy)
     Status: "Ready."
      Tasks: 3 (limit: 2265)
     Memory: 7.8M (peak: 8.3M)
        CPU: 113ms
     CGroup: /system.slice/haproxy.service
             ├─2018 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -S /run/haproxy-master.sock
             └─2020 /usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -S /run/haproxy-master.sock

Jan 26 18:44:18 ubt-pg-aduron-cluster3 systemd[1]: Starting haproxy.service - HAProxy Load Balancer...
Jan 26 18:44:18 ubt-pg-aduron-cluster3 haproxy[2018]: [NOTICE]   (2018) : New worker (2020) forked
Jan 26 18:44:18 ubt-pg-aduron-cluster3 haproxy[2018]: [NOTICE]   (2018) : Loading success.
Jan 26 18:44:18 ubt-pg-aduron-cluster3 systemd[1]: Started haproxy.service - HAProxy Load Balancer.
```


<img src="img/4_haproxy/balance_roundrobin.png"/>



#### Конфигурация с учетом роли 

Дальше постарался создать долее служную конфигурацию
```sh
aduron@ubt-pg-aduron-cluster3:~$ sudo vi /etc/haproxy/haproxy.cfg

global
    daemon
    maxconn 4096
    log stdout local0
    stats socket /var/lib/haproxy/stats mode 660 level admin

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    log global

frontend postgres_ssl
    bind *:5432
    default_backend postgres_backend

backend postgres_backend
    option httpchk OPTIONS /master                                             
    http-check expect status 200
	  default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server ubt-pg-aduron-dbnode1 192.168.56.10:5432 check
    server ubt-pg-aduron-dbnode2 192.168.56.20:5432 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
```

однако при запуске столкнулся с такими ошибками как `Server postgres_backend/ubt-pg-aduron-dbnode1 is DOWN, reason: Socket error`
```sh
aduron@ubt-pg-aduron-cluster3:~$ sudo systemctl restart haproxy
Jan 26 19:13:57 ubt-pg-aduron-cluster3 systemd[1]: Started haproxy.service - HAProxy Load Balancer.
Jan 26 19:13:57 ubt-pg-aduron-cluster3 haproxy[2278]: [WARNING]  (2278) : Server postgres_backend/ubt-pg-aduron-dbnode1 is DOWN, reason: Socket error, check duration: 5ms. 1 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
Jan 26 19:13:57 ubt-pg-aduron-cluster3 haproxy[2278]: <129>Jan 26 19:13:57 haproxy[2278]: Server postgres_backend/ubt-pg-aduron-dbnode1 is DOWN, reason: Socket error, check duration: 5ms. 1 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
Jan 26 19:13:58 ubt-pg-aduron-cluster3 haproxy[2278]: [WARNING]  (2278) : Server postgres_backend/ubt-pg-aduron-dbnode2 is DOWN, reason: Socket error, check duration: 10ms. 0 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
Jan 26 19:13:58 ubt-pg-aduron-cluster3 haproxy[2278]: <129>Jan 26 19:13:58 haproxy[2278]: Server postgres_backend/ubt-pg-aduron-dbnode2 is DOWN, reason: Socket error, check duration: 10ms. 0 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
Jan 26 19:13:58 ubt-pg-aduron-cluster3 haproxy[2278]: [ALERT]    (2278) : backend 'postgres_backend' has no server available!
```

Как описано в документации, HAProxy использует такой же API REST как patronictl (а мы уже знаем что та утилита прекрасно справляется в нашей конфиге). Так что я решил проверить, в чем проблем с этим API.
Проблем нет, однако без сертификата можно толко запросить его с флогом --insecure

```sh
(patroni) postgres@ubt-pg-aduron-dbnode1:~$ curl --insecure https://192.168.56.10:8008/master
{"state": "running", "postmaster_start_time": "2026-01-26 18:11:42.051548+00:00", "role": "primary", "server_version": 180001, "xlog": {"location": 24849080}, "timeline": 13, "replication": [{"usename": "replicator", "application_name": "ubt-pg-aduron-dbnode2", "client_addr": "192.168.56.20", "state": "streaming", "sync_state": "sync", "sync_priority": 1}], "dcs_last_seen": 1769456261, "tags": {"clonefrom": true, "failover_priority": 1, "sync_priority": 1}, "database_system_identifier": "7590773680200294160", "patroni": {"version": "4.1.0", "scope": "18/main", "name": "ubt-pg-aduron-dbnode1"}}(patroni) postgres@ubt-pg-aduron-dbnode1:~$
```

Видимо HAProxy не может этого понимать, значит нужно найти способ пользоваться тут нашими любимыми сертификатами. В curl нет сложности, работает с флагами --cacert, --cert, и --key (всё же как etcdctl). 
Проверка:
```sh
root@ubt-pg-aduron-cluster3:~# curl -k https://192.168.56.10:8008/cluster  --cacert /etc/default/etcd/.tls/ca.crt --cert  /etc/default/etcd/.tls/ubt-pg-aduron-cluster3.crt --key /etc/default/etcd/.tls/ubt-pg-aduron-cluster3.key  | jq .
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   661    0   661    0     0   9077      0 --:--:-- --:--:-- --:--:--  9180
{
  "members": [
    {
      "name": "ubt-pg-aduron-dbnode1",
      "role": "leader",
      "state": "running",
      "api_url": "https://192.168.56.10:8008/patroni",
      "host": "192.168.56.10",
      "port": 5432,
      "timeline": 13,
      "tags": {
        "clonefrom": true,
        "failover_priority": 1,
        "sync_priority": 1
      }
    },
    {
      "name": "ubt-pg-aduron-dbnode2",
      "role": "sync_standby",
      "state": "streaming",
      "api_url": "https://192.168.56.20:8008/patroni",
      "host": "192.168.56.20",
      "port": 5432,
      "timeline": 13,
      "tags": {
        "clonefrom": true,
        "failover_priority": 1,
        "sync_priority": 1
      },
      "receive_lag": 0,
      "receive_lsn": "0/17B2AB8",
      "replay_lag": 0,
      "replay_lsn": "0/17B2AB8",
      "lag": 0,
      "lsn": "0/17B2AB8"
    }
  ],
  "scope": "18/main"
}
```

В haproxy, нет таких флагов, делается методом [комбинорования сертификата и ключа](https://www.percona.com/blog/securing-patroni-rest-api-end-points-part-2-using-ssl-certificates/). Работает он следующим образом:

Записываем сертификат нода вместе с ключом в одном файле
```sh
root@ubt-pg-aduron-cluster3:~# cat /etc/default/etcd/.tls/ubt-pg-aduron-cluster3.crt /etc/default/etcd/.tls/ubt-pg-aduron-cluster3.key > combined.crt
root@ubt-pg-aduron-cluster3:~# chmod 777 combined.crt
```
копируем комбинированный сертификат в `/etc/haproxy`. Также копируем сертификат ca. 
```sh
aduron@ubt-pg-aduron-cluster3:~$ sudo cp /root/combined.crt /etc/haproxy
aduron@ubt-pg-aduron-cluster3:~$ sudo cp /etc/default/etcd/.tls/ca.crt /etc/haproxy
aduron@ubt-pg-aduron-cluster3:~$ cd /etc/haproxy
aduron@ubt-pg-aduron-cluster3:/etc/haproxy$ ls -lrt
total 28
-rw-r--r-- 1 root root 1285 Dec  3 15:12 haproxy.cfg.backup_26012026
drwxr-xr-x 2 root root 4096 Jan 26 18:12 errors
-rw-r--r-- 1 root root  702 Jan 26 19:06 haproxy.cfg_loadbalance
-rw-r--r-- 1 root root  941 Jan 26 19:53 haproxy.cfg
-rwxr-xr-x 1 root root 5354 Jan 26 19:54 combined.crt
-rw-r--r-- 1 root root 2045 Jan 26 19:54 ca.crt
```

Затем бэкенд меняем вот так:
```sh
backend postgres_backend
    option httpchk OPTIONS /master
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server ubt-pg-aduron-dbnode1 192.168.56.10:5432 check check-ssl verify none port 8008 crt /etc/haproxy/combined.crt ca-file /etc/haproxy/ca.crt
    server ubt-pg-aduron-dbnode2 192.168.56.20:5432 check check-ssl verify none port 8008 crt /etc/haproxy/combined.crt ca-file /etc/haproxy/ca.crt
```

Перезапускаем *haproxy*. Сразу видно, что сервер у которого роль *replica* отображается как *DOWN*.
```sh
Jan 26 20:12:32 ubt-pg-aduron-cluster3 haproxy[2614]: [NOTICE]   (2614) : Loading success.
Jan 26 20:12:32 ubt-pg-aduron-cluster3 systemd[1]: Started haproxy.service - HAProxy Load Balancer.
Jan 26 20:12:34 ubt-pg-aduron-cluster3 haproxy[2617]: [WARNING]  (2617) : Server postgres_backend/ubt-pg-aduron-dbnode2 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable", check duration: 31ms. 1 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
Jan 26 20:12:34 ubt-pg-aduron-cluster3 haproxy[2617]: <129>Jan 26 20:12:34 haproxy[2617]: Server postgres_backend/ubt-pg-aduron-dbnode2 is DOWN, reason: Layer7 wrong status, code: 503, info: "Service Unavailable", check duration: 31ms. 1 active and 0 backup servers left. 0 sessions active, 0 requeued, 0 remaining in queue.
```

Проверяем, к какому серверу подключаемся через haproxy (то есть с этого хоста с портом фронтенда):
```sql
aduron@ubt-pg-aduron-cluster3:/etc/haproxy$ psql 'postgresql://postgres:Oracle123@localhost:5432/postgres'
psql (18.1 (Ubuntu 18.1-1.pgdg24.04+2))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
Type "help" for help.

postgres=# SELECT inet_server_addr() as ip, CASE WHEN pg_is_in_recovery() THEN 'Replica' ELSE 'Primary' END as role;
      ip       |  role
---------------+---------
 192.168.56.10 | Primary
(1 row)
```

Проверяем, через API `/stats`:

<img src="img/4_haproxy/correct_check.png"/>


#### Проверка переключения (switchover)

Выполняем switchover через Patroni.
```sh
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml switchover --leader ubt-pg-aduron-dbnode1 --candidate ubt-pg-aduron-dbnode2 18/main
Current cluster topology
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Leader       | running   | 13 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Sync Standby | streaming | 13 |   0/17B2AB8 |   0 |  0/17B2AB8 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
When should the switchover take place (e.g. 2026-01-26T21:17 )  [now]:
Are you sure you want to switchover cluster 18/main, demoting current leader ubt-pg-aduron-dbnode1? [y/N]: y
2026-01-26 20:18:10.73505 Successfully switched over to "ubt-pg-aduron-dbnode2"
+ Cluster: 18/main (7590773680200294160) ---------+---------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role    | State   | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Replica | stopped |    |     unknown |     |    unknown |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader  | running | 13 |             |     |            |     | clonefrom: true      |
|                       |               |         |         |    |             |     |            |     | failover_priority: 1 |
|                       |               |         |         |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+---------+---------+----+-------------+-----+------------+-----+----------------------+
(patroni) postgres@ubt-pg-aduron-dbnode2:~$
(patroni) postgres@ubt-pg-aduron-dbnode2:~$ patronictl -c /etc/patroni/config.yml list 18/main
+ Cluster: 18/main (7590773680200294160) --------------+-----------+----+-------------+-----+------------+-----+----------------------+
| Member                | Host          | Role         | State     | TL | Receive LSN | Lag | Replay LSN | Lag | Tags                 |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode1 | 192.168.56.10 | Sync Standby | streaming | 14 |   0/17B2D68 |   0 |  0/17B2D68 |   0 | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
| ubt-pg-aduron-dbnode2 | 192.168.56.20 | Leader       | running   | 14 |             |     |            |     | clonefrom: true      |
|                       |               |              |           |    |             |     |            |     | failover_priority: 1 |
|                       |               |              |           |    |             |     |            |     | sync_priority: 1     |
+-----------------------+---------------+--------------+-----------+----+-------------+-----+------------+-----+----------------------+
```

при попытке выполнить запрос, psql замечает, что потерялось соединение. При этом, он сразу пытается переключиться. Видно и здесь что Leader (Primary) находится теепер на *ubt-pg-aduron-dbnode2*:
```sql
postgres=# SELECT inet_server_addr() as ip, CASE WHEN pg_is_in_recovery() THEN 'Replica' ELSE 'Primary' END as role;
SSL error: unexpected eof while reading
The connection to the server was lost. Attempting reset: Succeeded.
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off, ALPN: postgresql)
postgres=# SELECT inet_server_addr() as ip, CASE WHEN pg_is_in_recovery() THEN 'Replica' ELSE 'Primary' END as role;
      ip       |  role
---------------+---------
 192.168.56.20 | Primary
(1 row)
```

API `/stats` показывает так же:

<img src="img/4_haproxy/correct_check_switchover.png"/>




## Итог проекта





## Список использованных источников:

1. [Скачать Ubuntu Server 24.04 LTS](https://ubuntu.com/download/server)
2. [How to install etcd on Ubuntu](https://linuxconfig.org/how-to-install-etcd-on-ubuntu)
3. [Пример установления etcd](https://habr.com/ru/companies/jetinfosystems/articles/847872/?ysclid=mjwo79l286676759989)
4. [Cluster Id Mismatch - Reseting member ID](https://stackoverflow.com/questions/40585943/etcd-cluster-id-mistmatch)
5. [Официальный сайт Патрони](https://patroni.readthedocs.io/en/latest/installation.html)
6. [Документация Patroni - Configuration](https://patroni.readthedocs.io/en/latest/patroni_configuration.html)
7. [HAProxy - комбинорование сертификата и ключа SSL](https://www.percona.com/blog/securing-patroni-rest-api-end-points-part-2-using-ssl-certificates/).


## Замечания


<b id="f1">1</b> [Последный релиз etcd](https://github.com/etcd-io/etcd/releases/) [↩](#a1)
