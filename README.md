# Phicomm N1

## 00.Reference
* https://isolated.site/category/n1/
  * lots of good research posts
  * inspired to reserve env/reserved partition as bad block and format single rootfs
  * ex4load works with disable 64-bit feature
* https://github.com/isjerryxiao/n1-setup/
  * physical partition offset list
* https://github.com/yangxuan8282/phicomm-n1
  * alpine version, not work in my N1 box
  * future research for pxe boot
* Telegram
  * https://t.me/flippingflooping
  * ?????
    * http://t.cn/Ew2ynzS ?? + ???????????????
    * http://t.cn/Ew2Lr3L ?? Android ??
    * http://t.cn/Ew2yk1X ? Linux
    * http://t.cn/Ew2ySQG Armbian Ubuntu ???
    * http://t.cn/Ew2yUh7 Armbian ?? dtb ??????
    * http://t.cn/Ew2LFK8 ??????

* https://github.com/150balbes
  * Amlogic kernel/uboot/armbian/etc. upstream
* http://linux-meson.com/doku.php
  * Linux for Amlogic Meson
* https://baylibre.com/category/amlogic/


## 01. U-Boot

### 01.1 logs/bins list
* [logs/uboot-help.log](logs/uboot-help.log)
* bins/bootloader.bin 
* bins/env.bin
* bins/reserved.bin
```
2097152 bootloader.bin
8388608 env.bin
4718592 reserved.bin
2.0M    bootloader.bin
8.0M    env.bin
4.5M    reserved.bin
1.2M    bootloader.bin.xz
3.1K    env.bin.xz
259K    reserved.bin.xz
```

### 01.2 uboot version and Android version
* 2015.01-00010-gfe36fb9-dirty (Mar 17 2018 - 12:20:04) [01 uboot version](u-boot.md)
* Android version = V2.28_0620

### 01.3 uboot stop auto boot Ctrl-C
```
Hit Enter or space or Ctrl+C key to stop autoboot -- :  0
gxl_p230_v1#<INTERRUPT>
```

### 01.4 u-boot firmware env location and size
* `/etc/fw_env.config`
* https://github.com/ARM-software/u-boot/blob/master/tools/env/fw_env.config
* https://elinux.org/U-boot_environment_variables_in_linux
* https://github.com/nerves-project/nerves_system_rpi3/blob/master/rootfs_overlay/etc/fw_env.config

* block device
  * /dev/mmcblk1 = block device
  * unit = Byte
  * 0x27400000 
    * `mmc env offset: 0x27400000` [02 saveenv](u-boot.md)
    * match env start offset with partition table
  * 0x10000 = 64 KiB 
    * `Environment size: 6028/65532 bytes` [02 env size](u-boot.md)
    ```
    # Device name  offset       Env. size    Flash sector size    Number of sectors
    /dev/mmcblk1   0x27400000   0x10000
    ```

* partition (Android ?)
  * /dev/env = partition
  * unit = Byte
  * offset = 0
  * Env. size = 0x10000 = 64 KiB
  * Flash sector size = 0x10000 = 64 KiB 
    > if the Flash sector size is ommitted, this value is assumed to be the same as the Environment size
    * ? sector size = Env. size, then number of sectors = 1 ?
    ```
    # Device name  offset       Env. size    Flash sector size    Number of sectors
    /dev/env       0x000000     0x10000      0x10000
    ```
### 01.5 bins
* [bins/env.bin](bins/env.bin)
  * serial = usid = SN15_0123456789
  * ethaddr = AA:BB:CC:DD:EE:FF = mac (option)
  * mac_wifi = AA:BB:CC:DD:EE:FE (option)
* [bins/bootloader.bin](bins/bootloader.bin)
  start offset/B | end offset/B |  size | Note
  -:|-:|-:|-
  0         | 0x1f0       | 0x200     | 1 x 512B, sector blank
  0x200     | 0x200000-1  |           | 2 MiB - 512 Byte = bootloader
  0x200000  | 0x400000-1  | 0x200000  | 2 MiB blank

```
dd if=bootloader.bin of=bootloader.bin.1 bs=1024 count=2048
dd if=bootloader.bin of=bootloader.bin.2 bs=1024 skip=2048
hexdump -C bootloader.bin.2
00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00200000
```

* [bins/reserved.bin](bins/reserved.bin)
  * https://isolated.site/2018/12/02/partition-table-format-of-phicomm-n1/
  * [refs/partition-table-format-of-phicomm-n1.md](refs/partition-table-format-of-phicomm-n1.md)

  start offset/B | end offset/B |  size | Note
  -:|-:|-:|-
  0         | 0x220-1     | 0x220     | 544B, partition table
  0x300000  | 0x320000-1  | 0x20000   | 128 KiB, 0xAA55
  0x400000  | 0x480000-1  | 0x80000   | 0.5 MiB, bin
  0x480000  | 0x4000000-1 |           | blank

```
dd if=reserved.bin of=reserved.bin.1 bs=1024 count=4608
dd if=reserved.bin of=reserved.bin.2 bs=1024 skip=4608
hexdump -C reserved.bin.2
00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
03b80000
```

* Partition table
* number_of_partitions = 0x0D = 13, match with 02.EMMC
```
PartitionTable:
    16bytes: [signature]  # = 'MPT\x0001.00.00\x00\x00\x00\x00'
    uint32: [number_of_partitions]
    array of `PartitionEntry`
    checksum of partition entries

PartitionEntry:
    16bytes: [lable]
    uint64: [size_in_bytes]
    uint64: [start_off_in_bytes]
    uint64: [mask]  # Defined in DTB. But what is it?
```
```
Offset      0  1  2  3  4  5  6  7   8  9  A  B  C  D  E  F

02400000   4D 50 54 00 30 31 2E 30  30 2E 30 30 00 00 00 00   MPT 01.00.00    
02400010   0D 00 00 00 97 1F E1 05  62 6F 6F 74 6C 6F 61 64       ??bootload
02400020   65 72 00 00 00 00 00 00  00 00 40 00 00 00 00 00   er        @     
02400030   00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00                   
02400040   72 65 73 65 72 76 65 64  00 00 00 00 00 00 00 00   reserved        
02400050   00 00 00 04 00 00 00 00  00 00 40 02 00 00 00 00             @     
02400060   00 00 00 00 00 00 00 00  63 61 63 68 65 00 00 00           cache   
02400070   00 00 00 00 00 00 00 00  00 00 10 00 00 00 00 00                   
02400080   00 00 C0 06 00 00 00 00  02 00 00 00 00 00 00 00     ?            
02400090   65 6E 76 00 00 00 00 00  00 00 00 00 00 00 00 00   env             
024000A0   00 00 80 00 00 00 00 00  00 00 50 07 00 00 00 00     €       P     
024000B0   00 00 00 00 00 00 00 00  6C 6F 67 6F 00 00 00 00           logo    
024000C0   00 00 00 00 00 00 00 00  00 00 00 02 00 00 00 00                   
024000D0   00 00 50 08 00 00 00 00  01 00 00 00 00 00 00 00     P             
024000E0   72 65 63 6F 76 65 72 79  00 00 00 00 00 00 00 00   recovery        
024000F0   00 00 00 02 00 00 00 00  00 00 C0 2A 00 00 00 00             ?    
02400100   01 00 00 00 00 00 00 00  72 73 76 00 00 00 00 00           rsv     
02400110   00 00 00 00 00 00 00 00  00 00 80 00 00 00 00 00             €     
02400120   00 00 40 2D 00 00 00 00  01 00 00 00 00 00 00 00     @-            
02400130   74 65 65 00 00 00 00 00  00 00 00 00 00 00 00 00   tee             
02400140   00 00 80 00 00 00 00 00  00 00 40 2E 00 00 00 00     €       @.    
02400150   01 00 00 00 00 00 00 00  63 72 79 70 74 00 00 00           crypt   
02400160   00 00 00 00 00 00 00 00  00 00 00 02 00 00 00 00                   
02400170   00 00 40 2F 00 00 00 00  01 00 00 00 00 00 00 00     @/            
02400180   6D 69 73 63 00 00 00 00  00 00 00 00 00 00 00 00   misc            
02400190   00 00 00 02 00 00 00 00  00 00 C0 31 00 00 00 00             ?    
024001A0   01 00 00 00 00 00 00 00  62 6F 6F 74 00 00 00 00           boot    
024001B0   00 00 00 00 00 00 00 00  00 00 00 02 00 00 00 00                   
024001C0   00 00 40 34 00 00 00 00  01 00 00 00 00 00 00 00     @4            
024001D0   73 79 73 74 65 6D 00 00  00 00 00 00 00 00 00 00   system          
024001E0   00 00 00 50 00 00 00 00  00 00 C0 36 00 00 00 00      P      ?    
024001F0   01 00 00 00 00 00 00 00  64 61 74 61 00 00 00 00           data    
02400200   00 00 00 00 00 00 00 00  00 00 C0 4A 01 00 00 00             繨    
02400210   00 00 40 87 00 00 00 00  04 00 00 00 00 00 00 00     @?     
```

## 02.EMMC partition table
block name <br> mmcblk0p | partition name <br> Notes | physical<br> start offset<br> hex | start<br> offset<br> K/M/GiB | partition<br> size<br> hex | size<br> K/M/GiB
:-:|-|-:|-:|-:|-:
0  | mmcblk0    | 0x0         | 0     | 0x1d2000000 | 7.28125 G
1  | bootloader | 0x0         | 0     | 0x400000    | 4 M
NA | safe gap   | 0x400000    | 4 M   | 0x2000000   | 32 M
2  | reserved   | 0x2400000   | 36 M  | 0x4000000   | 64 M
NA | safe gap   | 0x6400000   | 100 M | 0x800000    | 8 M
3  | cache      | 0x6c00000   | 108 M | 0x20000000  | 0.5 G
NA | safe gap   | 0x26c00000  |       | 0x800000    | 8 M
4  | env <br> bootargs, mac   | 0x27400000 | 0.613 G | 0x800000 | 8 M
NA | safe gap   | 0x27c00000  |         | 0x800000  | 8 M
5  | logo       | 0x28400000  | 0.629 G | 0x2000000 | 32 M
NA | safe gap   | 0x2a400000  |         | 0x800000  | 8 M
6  | recovery   | 0x2ac00000  | 0.668 G | 0x2000000 | 32 M
NA | safe gap   | 0x2cc00000  |         | 0x800000  | 8 M
7  | rsv        | 0x2d400000  | 0.707 G | 0x800000  | 8 M
NA | safe gap   | 0x2dc00000  |         | 0x800000  | 8 M
8  | tee        | 0x2e400000  | 0.723 G | 0x800000  | 8 M
NA | safe gap   | 0x2ec00000  |         | 0x800000  | 8 M
9  | crypt      | 0x2f400000  | 0.738 G | 0x2000000 | 32 M
NA | safe gap   | 0x31400000  |         | 0x800000  | 8 M
10 | misc       | 0x31c00000  | 0.777 G | 0x2000000 | 32 M
NA | safe gap   | 0x33c00000  |         | 0x800000  | 8 M
11 | boot       | 0x34400000  | 0.816 G | 0x2000000 | 32 M
NA | safe gap   | 0x36400000  |         | 0x800000  | 8 M
12 | system     | 0x36c00000  | 0.855 G | 0x50000000  | 1.25 G
NA | safe gap   | 0x86c00000  |         | 0x800000    | 8 M
13 | data       | 0x87400000<br>0x1d2000000| 2.113 G  | 0x14ac00000 | 5.168 G
96 | mmcblk0rpmb |||| 512 K
32 | mmcblk0boot0 |||| 4 M
64 | mmcblk0boot1 |||| 4 M


### 02.1   Android OS root password and part table
* root password 31183118
  ```
  p230:/ $ su
  Please enter password!
  31183118
  ```
```
p230:/ # cat /proc/partitions
major     minor #blocks name (1024 Byte=1KiB per block)
253        0     512000 zram0
179        0    7634944 mmcblk0
179        1       4096 mmcblk0p1
179        2      65536 mmcblk0p2
179        3     524288 mmcblk0p3
179        4       8192 mmcblk0p4
179        5      32768 mmcblk0p5
179        6      32768 mmcblk0p6
179        7       8192 mmcblk0p7
179        8       8192 mmcblk0p8
179        9      32768 mmcblk0p9
179       10      32768 mmcblk0p10
179       11      32768 mmcblk0p11
179       12    1310720 mmcblk0p12
179       13    5419008 mmcblk0p13
179       96       4096 mmcblk0rpmb
179       64       4096 mmcblk0boot1
179       32       4096 mmcblk0boot0

major    minor  #blocks name (1024 Byte=1KiB per block)
179        0    7634944 mmcblk0
179        1       4096 bootloader
179        2      65536 reserved
179        3     524288 cache
179        4       8192 env             bootargs,mac
179        5      32768 logo
179        6      32768 recovery
179        7       8192 rsv             NULL
179        8       8192 tee             NULL
179        9      32768 crypt           NULL
179       10      32768 misc            NULL
179       11      32768 boot
179       12    1310720 system
179       13    5419008 data
179       96       4096 mmcblk0rpmb
179       64       4096 mmcblk0boot1
179       32       4096 mmcblk0boot0
```

### 02.2 emmc part table
* mmcblk0rpmb have diff size 4096 vs 512 ?
* from Telegram https://t.me/phicomm_n1 
```
179       96       512 mmcblk0rpmb
```

* What are below 3 x parts?
  * mmcblk1boot0
  * mmcblk1boot1
  * mmcblk1rpmb
* https://isolated.site/2019/06/06/use-single-partition-to-boot-linux-on-phicomm-n1/
* [refs/use-single-partition-to-boot-linux-on-phicomm-n1.md](refs/use-single-partition-to-boot-linux-on-phicomm-n1.md)
* https://www.digi.com/resources/documentation/digidocs/90001547/reference/bsp/v4-9_6ul/r_mmc-sd-sdio_6ul.htm
  > Note that the documentation is for ConnectCore 6UL SBC Pro, but the idea about eMMC remains the same.

### 02.3 emmc physical offset refer
* https://github.com/isjerryxiao/n1-setup/blob/master/offset.sh
* [refs/offset.sh](refs/offset.sh)
```
offset.sh
Help you modify each emmc partiton
Usage: offset.sh [-d] partition
```
```
_bootloader="bootloader 0x000000000000 0x000000400000"
_reserved="reserved 0x000002400000 0x000004000000"
_cache="cache 0x000006c00000 0x000020000000"
_env="env 0x000027400000 0x000000800000"
_logo="logo 0x000028400000 0x000002000000"
_recovery="recovery 0x00002ac00000 0x000002000000"
_rsv="rsv 0x00002d400000 0x000000800000"
_tee="tee 0x00002e400000 0x000000800000"
_crypt="crypt 0x00002f400000 0x000002000000"
_misc="misc 0x000031c00000 0x000002000000"
_boot="boot 0x000034400000 0x000002000000"
_system="system 0x000036c00000 0x000050000000"
_data="data 0x000087400000 0x00014ac00000"
_all="bootloader reserved cache env logo recovery rsv tee crypt misc boot system data"
```

### 02.4 emmc single partition
Partition | used | all | unit | Notes
-|-:|-:|-|-
bootloader |  2  | 4  | MiB | keep all 4MiB for compatibility
reserved   | 4.5 | 64 | MiB | keep 4.5 MiB 0x480000 data
env        | 64K | 8  | MiB | keep  64 KiB  0x10000 data
logo       |  8  | 32 | MiB | keep 32 MiB, not need for me

* https://isolated.site/2019/06/06/use-single-partition-to-boot-linux-on-phicomm-n1/
* [refs/use-single-partition-to-boot-linux-on-phicomm-n1.md](refs/use-single-partition-to-boot-linux-on-phicomm-n1.md)
```
# Mark reserved regions as bad block to prevent Linux from using them.
# /dev/env: This "device" (present in Linux 3.x) uses 0x27400000 ~ +0x800000.
#           It seems that they're overwritten each time system boots if value
#           there is invalid. Therefore we must not touch these blocks.
#
# /dev/logo: This "device"  uses 0x28400000~ +0x800000. You may mark them as
#            bad blocks if you want to preserve or replace the boot logo.
#
# All other "devices" (i.e., `recovery`, `rsv`, `tee`, `crypt`, `misc`, `boot`,
# `system`, `data` should be safe to overwrite.)
```

## 03.Armbian or linux

### 03.1 mount image
MacOS
extract zip/7z file and double click the *.img

```
diskutil list /dev/disk2
/dev/disk2 (disk image):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        +1.7 GB     disk2
   1:             Windows_FAT_16 BOOT                    134.2 MB   disk2s1
   2:                      Linux                         1.6 GB     disk2s2
```

* mount BOOT partition as BOOOT
  * `diskutil unmount /Volumes/BOOT`
* mount ROOTFS
  * `ext4fuse /dev/disk2s2 armbianbuster`
  * `diskutil unmount armbianbuster`

* copy script out
* must su - root, mount rootfs

```
root# ls -l
total 40
-r--r--r--  1 root  wheel  3523 Jun 18 14:38 .bashrc
-r--r--r--  1 root  wheel     0 Jun 18 14:38 .desktop_autologin
-r--r--r--  1 root  wheel     0 Jun 18 14:38 .not_logged_in_yet
-r--r--r--  1 root  wheel   148 Aug 17  2015 .profile
-r--r--r--  1 root  wheel   261 Jun 18 14:41 fstab
-r-xr-xr-x  1 root  wheel  3355 Jun 18 14:41 install-2018.sh
-r-xr-xr-x  1 root  wheel  3296 Jun 18 14:41 install.sh
root# cat fstab
#/var/swap none swap sw 0 0
#/dev/root	/		auto		noatime,errors=remount-ro	0 1
#proc		/proc		proc		defaults				0 0

/dev/root	/		ext4		defaults,noatime,errors=remount-ro	0 1
tmpfs		/tmp		tmpfs		defaults,nosuid				0 0
LABEL=BOOT_EMMC	/boot		vfat		defaults				0 2
# cp install.sh ../../install.sh-Armbian_5.89_Aml-s905_Debian_buster_default_5.1.0_20190617.img

/usr/sbin/nand-sata-install link to  /root/install.sh


armbianbuster root# file usr/bin/ddbr*
usr/bin/ddbr:                  Bourne-Again shell script text executable, ASCII text
usr/bin/ddbr_backup_nand:      POSIX shell script text executable, ASCII text
usr/bin/ddbr_backup_nand_full: POSIX shell script text executable, ASCII text
usr/bin/ddbr_restore_nand:     POSIX shell script text executable, ASCII text

```


