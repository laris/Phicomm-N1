# USE SINGLE PARTITION TO BOOT LINUX ON PHICOMM N1
* https://isolated.site/2019/06/06/use-single-partition-to-boot-linux-on-phicomm-n1/

[Carrot](https://isolated.site/author/carrot/ "View all posts by Carrot") __

<time class="entry-date published updated" datetime="2019-06-06T11:19:10+00:00"><a href="https://isolated.site/2019/06/06/use-single-partition-to-boot-linux-on-phicomm-n1/" data-slimstat="5">2019-06-06</a></time>

**All your data will be lost if you do something wrong. Don’t follow this post unless you’re ABSOLUTELY aware of what you’re doing.**

Well, this idea has come to me for some time, but I didn’t want bother doing that until yesterday, when I upgraded my box to Linux 5.1.7.

`ext4load` supports path (rather than file names only), so it’s possible to ask it to load files in `/boot`.

Firstly I repartitioned my eMMC, create a single (large) partition starts at 100M, the script I used is posted below.

There are several caveats here, though:

1.  You may not create the partition from the beginning of the eMMC. Or you’ll be in trouble. (Those blocks are used by bootloader, etc., and are “reserved”.)
2.  [Feature `64bit` of `ext4`](http://man7.org/linux/man-pages/man5/ext4.5.html) must be turned off, since it’s not recognized by U-boot. (This took me some time to realize, thanks to [a comment on StackOverflow](https://stackoverflow.com/questions/38632216/load-u-boot-ldr-in-bf548-ezkit-using-sd-card/38659570#comment64694583_38632216).) You can find more discussions [here](https://serverfault.com/questions/950704/mkfs-o-64bit-metadata-csum-t-ext4-in-2019). I kept `metadata_csum`, as I didn’t see troubles with it (I’m still testing with it. I may turn out to be wrong.). This is also done by the script.

3.  Several blocks may not be used by Linux, they’re marked as “bad block”s by the script.

4.  The script also backup and restores the first 4M of `/dev/mmcblk1` (except for partition table). I copied them from [an earlier script](https://isolated.site/2018/12/08/my-script-for-installing-armbian-5-67-into-phicomm-n1/). IIUC this is not strictly required, as the first sector should be not used by U-boot anyway. But I didn’t test that.

```
#/usr/bin/env bash
set -e

# So as to not overwrite U-boot, we backup the first 1M.
dd if=/dev/mmcblk1 of=/tmp/boot-bak bs=1M count=4

# (Re-)initialize the eMMC and create a partition.
#
# `bootloader` / `reserved` occupies [0, 100M). Since sector size is 512B, byte
# offset would be 204800.
parted -s /dev/mmcblk1 mklabel msdos
parted -s /dev/mmcblk1 unit s mkpart primary ext4 204800 100%

# Restore U-boot (except the first 442 bytes, where partition table is stored.)
dd if=/tmp/boot-bak of=/dev/mmcblk1 conv=fsync bs=1 count=442
dd if=/tmp/boot-bak of=/dev/mmcblk1 conv=fsync bs=512 skip=1 seek=1

# This method is used to convert byte offset in `/dev/mmcblk1` to block offset
# in `/dev/mmcblk1p1`.
as_block_number() {
    # Block numbers are offseted by 100M since `/dev/mmcblk1p1` starts at 100M
    # in `/dev/mmcblk1`.
    #
    # Because we're using 4K blocks, the byte offsets are divided by 4K.
    expr $((($1 - 100 * 1024 * 1024) / 4096))
}

# This method generates a sequence of block number in range [$1, $1 + $2).
#
# It's used for marking several reserved regions as bad blocks below.
gen_blocks() {
    seq $(as_block_number $1) $(($(as_block_number $(($1 + $2))) - 1))
}

# Mark reserved regions as bad block to prevent Linux from using them.
#
# /dev/env: This "device" (present in Linux 3.x) uses 0x27400000 ~ +0x800000.
#           It seems that they're overwritten each time system boots if value
#           there is invalid. Therefore we must not touch these blocks.
#
# /dev/logo: This "device"  uses 0x28400000~ +0x800000. You may mark them as
#            bad blocks if you want to preserve or replace the boot logo.
#
# All other "devices" (i.e., `recovery`, `rsv`, `tee`, `crypt`, `misc`, `boot`,
# `system`, `data` should be safe to overwrite.)
gen_blocks 0x27400000 0x800000 > /tmp/reservedblks
echo "Marked blocks used by /dev/env as bad."

# Let's see if a boot logo is to be installed.
if [ -e /boot/n1-logo.img ]; then
    dd if=/boot/n1-logo.img of=/dev/mmcblk1 bs=1M seek=644
    echo "Boot logo installed."
    gen_blocks 0x28400000 0x800000 >> /tmp/reservedblks
    echo "Marked blocks used by /dev/logo as bad."
fi

# Format the partition. Feature `64bit` of ext4 is disabled.
mke2fs -F -q -O ^64bit -t ext4 -m 0 /dev/mmcblk1p1 -b 4096 -l /tmp/reservedblks

# Flush changes (in case they were cached.).
sync
echo "Partition table (re-)initialized."
```

Then I needed to change `start_emmc_autoscript` to load `boot.ini` ([this is my substitute for `uEnv.ini`](https://isolated.site/2019/03/16/boot-phicomm-n1-without-emmc_autoscript-s905_autoscript/)) from `/boot`:

` fw_setenv start_emmc_autoscript 'if ext4load mmc 1 ${env_addr} /boot/boot.ini; then env import -t ${env_addr} ${filesize}; if ext4load mmc 1 ${kernel_addr} ${image}; then if ext4load mmc 1 ${initrd_addr} ${initrd}; then if ext4load mmc 1 ${dtb_mem_addr} ${dtb}; then run boot_start;fi;fi;fi;fi;' `

.. and change `/boot/boot.ini` accordingly:
```
image=/boot/vmlinuz-5.1.7
initrd=/boot/uInitrd
dtb=/boot/meson-gxl-s905d-phicomm-n1.dtb
bootargs=root=/dev/mmcblk1p1 rootflags=data=writeback rw console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0
```
`/etc/fstab` need to be updated to reflect the change that `/boot` is no longer a separate parition.

If you used UUIDs in specifying partitions / `bootargs`, those UUIDs must also be updated.

This is how the system looks like now:
```
[root@n1-box ~]# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/mmcblk1p1  7.1G  1.0G  6.1G  16% /
...
```


8 thoughts on “Use single partition to boot Linux on Phicomm N1”
major says: 2019-06-08 at 11:47
how to upgraded N1 to Linux 5.1.7?

Reply
Carrot says: 2019-06-08 at 12:08
I compiled Linux 5.1.7 myself. Instructions of compiling Linux 4.20 were posted here
https://isolated.site/2018/12/31/built-debian-9-4-20-kernel-for-my-n1-box/
, the same apply to Linux 5.x. Several patches are required for vanilla Linux 5.x to boot on Phicomm N1, they were posted here
https://isolated.site/2019/03/05/several-patches-im-using-for-running-linux-5-0-on-phicomm-n1/

major says: 2019-06-08 at 12:41
thx~, and can u share ur kernel .config file ?

Carrot says: 2019-06-08 at 13:28
I’m not sure my .config suits your need, as I disabled several features (such as video / bluetooth / wireless networking) I don’t use. However, you may want to see Armbian’s (https://disk.yandex.ru/d/pHxaRAs-tZiei/5.88/s9xxx, in the first partition labeled “BOOT”), on which my .config is based. Their .config is intended for general use.

echo says: 2019-06-11 at 10:27
Ohmm,

I’m trying to setup also:
1, only-one-emmc root partition without vfat boot
2, with yandex’s netdisk 5.88
3, Armbian_5.88_Aml-s905_Ubuntu_bionic_default_5.1.0_20190607.img
4, change install.sh

And got some confusion about:
1, where the bootloader store in original mmc?
2, why bootloader occupy 100MiB ? from dmesg, mmcblk1boot0 only 4MiB
# bootloader / reserved occupies [0, 100M). Since sector size is 512B, byte
# offset would be 204800.

root@aml:/etc# dmesg|grep mmc
[ 3.041669] meson-gx-mmc d0072000.mmc: Got CD GPIO
[ 3.071952] meson-gx-mmc d0074000.mmc: allocated mmc-pwrseq
[ 3.205883] mmc1: new HS200 MMC card at address 0001
[ 3.210891] mmcblk1: mmc1:0001 NCard 7.28 GiB
[ 3.211539] mmcblk1boot0: mmc1:0001 NCard partition 1 4.00 MiB
[ 3.216304] mmcblk1boot1: mmc1:0001 NCard partition 2 4.00 MiB
[ 3.221716] mmcblk1rpmb: mmc1:0001 NCard partition 3 4.00 MiB, chardev (241:0)

3, What’s mean of below 3 x part?
mmcblk1boot0
mmcblk1boot1
mmcblk1rpmb

4, 20190607 version looks like ext4load cannot read /boot dir
5, about /etc/fw_env.config, how to test to get hardcoded 0x27400000? how to convert into fw_env.config?

https://isolated.site/2018/12/08/my-script-for-installing-armbian-5-67-into-phicomm-n1/
It seems that u-boot on Phicomm N1 hardcoded 0x27400000 for reading / storing its environment variables, and is overwritten with default values even when it’s invalid (from u-boot’s parser’s perspective).

6, could you publish your code to github then we can fork and customize some features? like remove logo option.

Thanks,

Carrot says: 2019-06-11 at 14:09
1/2. To my knowledge, /dev/mmcblk1boot* is physically separated from /dev/mmcblk1, therefore their size have nothing to do with how much space should be reserved on /dev/mmcblk1.

Reserving the first 100M is only “sufficient”, but not “necessary”. I didn’t have a thorough test / analysis about how much space should be reserved. However, if my memory serves me well, overwriting blocks near the beginning of /dev/mmcblk1 bricked my box, so I believe that they’re used for booting (at least in some later stage) or by bootloader.

bootloader / reserved mentioned in the script referred to partitions in [N1’s partition table](https://isolated.site/2018/12/02/partition-table-format-of-phicomm-n1/), instead of the real “bootloader” (although the real bootloader is probably there, at least, bootloader for some stages.). The bootloader (the program) itself by no means should occupy 100MB.

As for whether /dev/mmcblk1boot* is being used for booting, I saw several sources stating that they were not, but I couldn’t be sure if those sources applied to Amlogic. I haven’t tried overwriting /dev/mmcblk1 from the first byte, so I couldn’t confirm this.

3. See https://www.digi.com/resources/documentation/digidocs/90001547/reference/bsp/v4-9_6ul/r_mmc-sd-sdio_6ul.htm. Note that the documentation is for ConnectCore 6UL SBC Pro, but the idea about eMMC remains the same.

4. I’m not aware that U-boot on N1 could be upgraded, as it seemed to be signed (RSA2048), and Phicomm and / or Amlogic did not provide a newer one for N1. Would you mind provide your source of newer version of U-boot on N1? Or are you using a device from other OEMs?

5. See [this post](https://isolated.site/2018/12/23/get-fw_printenv-working-on-phicomm-n1/). If you’re using a different device, a simple way would be grep-ing some variable in /dev/mmcblk1.

6. I haven’t prepared a GitHub account for N1 stuff, sorry about that. :/


