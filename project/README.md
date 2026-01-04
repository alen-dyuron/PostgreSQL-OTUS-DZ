# Проектная работа

## Тема

Создание и тестирование высоконагруженного отказоустойчивого кластера PostgreSQL на базе Patroni

## Цель и задачи проекта

Цель проекта: Создать высокодоступный кластер PostgreSQL, развёртывание и обслуживание которого будут автоматизированы модулями Patroni и etcd, и тестировать отказоустойчивость кластера в рамках планированного и непланированного переключения роли.

- [x] Создание виртуалной кластеризованной среды Ubuntu c распределённом хранилищем конфигурации etcd
- [ ] Настраивание модули управления Patroni
- [ ] Тестирование переключения и отказоустойчивости кластера
- [ ] ...


> [!NOTE]
> Здесь показано галочками какие задачи были выполнены


## Архитектура

### Используеммые технрлогии

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







#### Клонирование первой виртуалной машины




### Настраивание модули управления Patroni



### Тестирование переключения и отказоустойчивости кластера




## Список использованных источников:

1. [Скачать Ubuntu Server 24.04 LTS](https://ubuntu.com/download/server)
2. [How to install etcd on Ubuntu](https://linuxconfig.org/how-to-install-etcd-on-ubuntu)
3.
4.


## Замечания


<b id="f1">1</b> [Последный релиз etcd](https://github.com/etcd-io/etcd/releases/) [↩](#a1)
