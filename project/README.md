# Проектная работа

## Тема

__Создание и тестирование высоконагруженного отказоустойчивого кластера PostgreSQL на базе Patroni__

## Цель и задачи проекта

Цель проекта: Создать высокодоступный кластер PostgreSQL, развёртывание и обслуживание которого будут автоматизированы модулями Patroni и etcd, и тестировать отказоустойчивость кластера в рамках планированного и непланированного переключения роли.

- [x] Создание виртуалной кластеризованной среды Ubuntu c распределённом хранилищем конфигурации etcd
- [ ] Настраивание модули управления Patroni
- [ ] Тестирование переключения и отказоустойчивости кластера
- [ ] ...


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
```
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

После много времени, пытаясь понимать чтоздесь произошло, стало понятнить что у нас здесь опять таки одно последствие клонирование. Причина в конце концов, нашел [здесь](https://stackoverflow.com/questions/40585943/etcd-cluster-id-mistmatch):


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


### Тестирование переключения и отказоустойчивости кластера


## Список использованных источников:

1. [Скачать Ubuntu Server 24.04 LTS](https://ubuntu.com/download/server)
2. [How to install etcd on Ubuntu](https://linuxconfig.org/how-to-install-etcd-on-ubuntu)
3. [Пример установления etcd](https://habr.com/ru/companies/jetinfosystems/articles/847872/?ysclid=mjwo79l286676759989)
4. [Cluster Id Mismatch - Reseting member ID](https://stackoverflow.com/questions/40585943/etcd-cluster-id-mistmatch)


## Замечания


<b id="f1">1</b> [Последный релиз etcd](https://github.com/etcd-io/etcd/releases/) [↩](#a1)
