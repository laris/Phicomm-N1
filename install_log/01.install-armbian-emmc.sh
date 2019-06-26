#!/usr/bin/env bash
set -x
# copy rootfs 
DEV_EMMC=/dev/mmcblk1
PART_ROOT=${DEV_EMMC}p1

DIR_INSTALL="/mnt"
INSTALL_LOG="/boot/install_log"

if grep -q $DIR_INSTALL /proc/mounts ; then
    echo "Unmounting ROOTFS."
    umount -f $PART_ROOT
fi

mkdir -p $DIR_INSTALL

mount $PART_ROOT $DIR_INSTALL
#-------------------------------------------------------------------------------
cd /boot
# get boot dir files name
file_kernel=$(ls vmlinuz-*)
file_initrd=$(ls uInitrd-*)
file_dtb=$(basename $(ls dtb/*phicomm-n1*))
file_config=$(ls config-*)
file_sysmap=$(ls System.map-*)
file_initrdimg=$(ls initrd.img-*)
# copy boot dir files to rootfs
mkdir -p $DIR_INSTALL/boot
cp \
  ${file_kernel} \
  ${file_initrd} \
  dtb/${file_dtb} \
  ${file_config} \
  ${file_sysmap} \
  ${file_initrdimg} \
  $DIR_INSTALL/boot/
chmod 644 $DIR_INSTALL/boot/*
cd $DIR_INSTALL/boot/
ln -sf ${file_kernel} zImage
ln -sf ${file_initrd} uInitrd
# generate cmd file
# if ext4load mmc 1 ${addr_env} ${file_bootini}; then 
#    env import -t ${addrenv} ${filesize};
# fi 
# if ext4load mmc 1 ${addr_kernel} ${file_kernel}; then 
#   if ext4load mmc 1 ${addr_initrd} ${file_initrd}; then 
#     if ext4load mmc 1 ${addr_dtb} ${file_dtb}; then
#       run boot_start;
#     fi;
#   fi;
# fi;
cat > "$DIR_INSTALL/boot/emmc_autoscript.cmd"<<'EOF'
setenv addr_env     "0x10400000"
setenv addr_kernel  "0x11000000"
setenv addr_initrd  "0x13000000"
setenv addr_dtb     "0x1000000"
setenv file_bootini "/boot/boot.ini"
setenv boot_start   booti ${addr_kernel} ${addr_initrd} ${addr_dtb}
if ext4load mmc 1 ${addr_env} ${file_bootini}; then env import -t ${addr_env} ${filesize}; fi; if ext4load mmc 1 ${addr_kernel} ${file_kernel}; then if ext4load mmc 1 ${addr_initrd} ${file_initrd}; then if ext4load mmc 1 ${addr_dtb} ${file_dtb}; then run boot_start; fi; fi; fi;
EOF
# generate cmd bin file
mkimage -C none -A arm64 -T script -d $DIR_INSTALL/boot/emmc_autoscript.cmd $DIR_INSTALL/boot/emmc_autoscript

# generate boot.ini
cat > "$DIR_INSTALL/boot/boot.ini"<<'EOF'
file_kernel=/boot/zImage
file_initrd=/boot/uInitrd
file_dtb=/boot/meson-gxl-s905d-phicomm-n1.dtb
EOF
# file_basepath="/boot/"
# file_kernel="${file_basepath}zImage"
# file_initrd="${file_basepath}uInitrd"
# file_dtb="${file_basepath}meson-gxl-s905d-phicomm-n1.dtb"
# EOF
cd /boot
cat uEnv.ini | grep bootargs | sed  "s/ROOTFS/ROOT_EMMC/g" >> "$DIR_INSTALL/boot/boot.ini"
#-------------------------------------------------------------------------------
# define copy_rootfs function
copy_rootfs(){
  option=$1 # 0 only create dir, 1 tar and copy all attr
  path_src=$2
  path_dst=$3
  dir=$4
  if [ $option = 0 ]; then
    mkdir -p $path_dst/$dir
  elif [ $option = 1 ]; then
    cd $path_src
    tar -cf - $dir | (cd $path_dst; tar -xpf -)
  else
    echo "ERR: option"
  fi
}
# copy rootfs exclue bin
for d in dev home media mnt proc run sys tmp; do
  copy_rootfs 0 "/" $DIR_INSTALL  $d
done
for d in bin etc lib opt root sbin selinux srv var usr; do
  copy_rootfs 1 "/" $DIR_INSTALL  $d
done
# update fstab, ROOTFS to ROOT_EMMC to avoid armbian usb img boot emmc rootfs
rm $DIR_INSTALL/etc/fstab
cp -af /root/fstab $DIR_INSTALL/etc/fstab
sed -e "s@^/dev/root@LABEL=ROOT_EMMC@g" \
    -e "s/^LABEL=BOOT_EMMC/#LABEL=BOOT_EMMC/g" \
    -i $DIR_INSTALL/etc/fstab
#-------------------------------------------------------------------------------
# Clean armbian scripts
for f in \
          /root/install.sh \
          /root/install-2018.sh \
          /usr/sbin/nand-sata-install \
          /root/fstab \
          /usr/bin/ddbr \
          /usr/bin/ddbr_backup_nand \
          /usr/bin/ddbr_backup_nand_full \
          /usr/bin/ddbr_restore_nand \
          ; do
  rm ${DIR_INSTALL}${f}
done
#-------------------------------------------------------------------------------
# update fw_env.config
# test if offset match to N1
grep 0x27400000 /etc/fw_env.config
if [ $? -ne 0 ]; then
cat >"/etc/fw_env.config"<<'EOF'
# Device to access      offset          env size
/dev/mmcblk1            0x27400000      0x10000
EOF
#mv /etc/fw_env.config /etc/fw_env.config.orig
cp -f /etc/fw_env.config $DIR_INSTALL/etc/fw_env.config
else 
echo "fw_env.config OK"
fi
#-------------------------------------------------------------------------------
# update fw_env
fw_setenv bootcmd "run start_autoscript"
fw_setenv start_autoscript "if usb start; then run start_usb_autoscript; fi; if mmcinfo; then run start_mmc_autoscript; fi; run start_emmc_autoscript;"
fw_setenv start_usb_autoscript "if fatload usb 0 1020000 s905_autoscript; then autoscr 1020000; fi; if fatload usb 1 1020000 s905_autoscript; then autoscr 1020000; fi; if fatload usb 2 1020000 s905_autoscript; then autoscr 1020000; fi; if fatload usb 3 1020000 s905_autoscript; then autoscr 1020000; fi;"
fw_setenv start_emmc_autoscript "if ext4load mmc 1 1020000 /boot/emmc_autoscript; then autoscr 1020000; fi;"
fw_setenv bootargs "root=LABEL=ROOT_EMMC rootflags=data=writeback rw console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0"
#-------------------------------------------------------------------------------
#post customization
NODE_META_LIST="${INSTALL_LOG}/node-list.txt"
#-------------------------------------------------------------------------------
# define func to get serial from fw env, then search/return meta info from list
get_node_value(){
  #node_list_file=$NODE_META_LIST
  # 1=SN,2=MAC,3=MAC_WIFI,4=HOSTNAME,5=ETH_IP,6=WIFI_IP,7=TIMEZONE,8=WIFI_SSID,9=WIWI_PWD
  node_meta_name=$1
  node_meta_sn=$(fw_printenv | grep serial= | cut -d "=" -f 2)
  if [ -e $node_list_file ]; then
    grep $node_meta_sn $NODE_META_LIST | cut -d ',' -f $node_meta_name
  fi
}
#-------------------------------------------------------------------------------
set_node_host_name(){
  node_hn=$(get_node_value 4)
  echo $node_hn > $DIR_INSTALL/etc/hostname
  sed -i 's/"//g' $DIR_INSTALL/etc/hostname
  sed -i -e "s/aml/$node_hn/g" -e 's/"//g' $DIR_INSTALL/etc/hosts
  #hostnamectl set-hostname $node_hn
}
set_node_host_name
#-------------------------------------------------------------------------------
set_node_tz(){
node_tz=$(echo $(get_node_value 7) | sed 's/"//g')
grep $node_tz $DIR_INSTALL/etc/timezone
if [ $? -ne 0 ]; then
#timezone
#https://serverfault.com/questions/94991/setting-the-timezone-with-an-automated-script
echo $node_tz > $DIR_INSTALL/etc/timezone
# 1
pushd .
cd $DIR_INSTALL/etc/
rm -rf localtime
ln -sf ../usr/share/zoneinfo/${node_tz} localtime
popd
# 2
#dpkg-reconfigure -f noninteractive tzdata
# 3
#Set time zone and time
#echo "tzdata tzdata/Areas select Europe" | debconf-set-selections
#echo "tzdata tzdata/Zones/Europe select London" | debconf-set-selections
#TIMEZONE="Europe/London"
#echo $TIMEZONE > /etc/timezone
#cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
#/usr/sbin/ntpdate pool.ntp.org
else
  echo "TimeZone $node_tz OK"
fi
}
set_node_tz
#-------------------------------------------------------------------------------
set_node_network(){ 
#network

node_ssid=$(get_node_value 8)
node_psk=$(echo $(get_node_value 9) | sed 's/"//g')
cat > "$DIR_INSTALL/etc/wpa_supplicant/wpa_supplicant.conf" <<EOF
network={
    ssid=$node_ssid
    psk=$node_psk
}
EOF
# network={
# 	ssid="Haojiahuo5"
# 	#psk="@qiaofeng"
# 	psk=2904fab989fbcb4926f9523a2f13d461c89776d5eeea6210b96fa23ece982f82
# }

node_mac=$(get_node_value 2)
node_macwifi=$(get_node_value 3)
node_ipeth=$(get_node_value 5)
node_ipwifi=$(get_node_value 6)

sed -i "/^[^#]/{s/^[^source]/#&/}"  "$DIR_INSTALL/etc/network/interfaces"

cat > "$DIR_INSTALL/etc/network/interfaces.d/wlan0" <<EOF
# Wireless adapter #1
# Armbian ships with network-manager installed by default. To save you time
# and hassles consider using 'sudo nmtui' instead of configuring Wi-Fi settings
# manually. The below lines are only meant as an example how configuration could
# be done in an anachronistic way:
#
auto wlan0
allow-hotplug wlan0
iface wlan0 inet dhcp
  hwaddress $node_macwifi
  metric 100
#address 192.168.0.100
#netmask 255.255.255.0
#gateway 192.168.0.1
#dns-nameservers 8.8.8.8 8.8.4.4
  wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
# Disable power saving on compatible chipsets (prevents SSH/connection dropouts over WiFi)
wireless-mode Managed
wireless-power off
EOF

cat > "$DIR_INSTALL/etc/network/interfaces.d/eth0" <<EOF
# Wired adapter #1
allow-hotplug eth0
no-auto-down eth0
iface eth0 inet dhcp
  hwaddress $node_mac
  metric 10
#address 192.168.0.100
#netmask 255.255.255.0
#gateway 192.168.0.1
#dns-nameservers 8.8.8.8 8.8.4.4
#	hwaddress ether # if you want to set MAC manually
#	pre-up /sbin/ifconfig eth0 mtu 3838 # setting MTU for DHCP, static just: mtu 3838
EOF

cat > "$DIR_INSTALL/etc/network/interfaces.d/lo" <<EOF
# Local loopback
auto lo
iface lo inet loopback
EOF
# 
rm -rf $DIR_INSTALL/etc/resolv.conf
cd $DIR_INSTALL/etc
ln -sf resolvconf/run/resolv.conf resolv.conf
cat /dev/null > $DIR_INSTALL/etc/resolvconf/resolv.conf.d/head
}
set_node_network
#-------------------------------------------------------------------------------
#locale
#/etc/locale.gen
#locale-gen
#-------------------------------------------------------------------------------
update_repo(){
#repo
sed "s@deb\ http://apt.armbian.com@deb\ [arch=arm64]\ http://mirrors.tuna.tsinghua.edu.cn/armbian/@" \
    -i $DIR_INSTALL/etc/apt/sources.list.d/armbian.list
#deb [arch=arm64] http://apt.armbian.com buster main buster-utils buster-desktop
#deb [arch=arm64] http://mirrors.tuna.tsinghua.edu.cn/armbian/ buster main buster-utils buster-desktop

# root@aml:/etc/apt# cat sources.list
# deb [arch=arm64] http://httpredir.debian.org/debian buster main contrib non-free
# #deb-src [arch=arm64,armhf] http://httpredir.debian.org/debian buster main contrib non-free
# deb [arch=arm64] http://httpredir.debian.org/debian buster-updates main contrib non-free
# #deb-src [arch=arm64,armhf] http://httpredir.debian.org/debian buster-updates main contrib non-free
# deb [arch=arm64] http://httpredir.debian.org/debian buster-backports main contrib non-free
# #deb-src [arch=arm64,armhf] http://httpredir.debian.org/debian buster-backports main contrib non-free
# deb [arch=arm64] http://security.debian.org/ buster/updates main contrib non-free
# #deb-src [arch=arm64,armhf] http://security.debian.org/ buster/updates main contrib non-free

mv $DIR_INSTALL/etc/apt/sources.list $DIR_INSTALL/etc/apt/sources.list.orig
cat > "$DIR_INSTALL/etc/apt/sources.list" <<'EOF'
deb [arch=arm64] https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
# deb-src [arch=arm64,armhf] https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free
deb [arch=arm64] https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
# deb-src [arch=arm64,armhf] https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free
deb [arch=arm64] https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
# deb-src [arch=arm64,armhf] https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free
deb [arch=arm64] https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
# deb-src [arch=arm64,armhf] https://mirrors.tuna.tsinghua.edu.cn/debian-security buster/updates main contrib non-free
EOF
}
update_repo
#-------------------------------------------------------------------------------
setup_ssh_key(){
ssh_key_pri_1=id_rsa
ssh_key_pub_1=id_rsa.pub
ssh_key_pri_2=id_rsa.armbian
ssh_key_pub_2=id_rsa.armbian.pub

if [ -e $ssh_key_pri_1 -a -e $ssh_key_pub_1 ]; then
  mkdir -p $DIR_INSTALL/root/.ssh
  cp $ssh_key_pri_1 $ssh_key_pub_1 $DIR_INSTALL/root/.ssh/
  cd $DIR_INSTALL/root/.ssh
  ln -sf $ssh_key_pub_1 authorized_keys
  #ln -sf $ssh_key_pub_1 id_rsa.pub
  chmod 700 $DIR_INSTALL/root/.ssh
  chmod 600 $DIR_INSTALL/root/.ssh/*
elif [ -e $ssh_key_pri_2 -a -e $ssh_key_pub_2 ]; then
  mkdir -p $DIR_INSTALL/root/.ssh
  cp $ssh_key_pri_2 $ssh_key_pub_2 $DIR_INSTALL/root/.ssh/
  cd $DIR_INSTALL/root/.ssh
  ln -sf $ssh_key_pub_2 authorized_keys
  ln -sf $ssh_key_pri_2 $ssh_key_pri_1
  ln -sf $ssh_key_pub_2 $ssh_key_pub_1
  chmod 700 $DIR_INSTALL/root/.ssh
  chmod 600 $DIR_INSTALL/root/.ssh/*
else 
  ssh-keygen -t rsa -C "Armbian ssh key" -q -N "" -f $ssh_key_pri_2
  mkdir -p $DIR_INSTALL/root/.ssh
  cp $ssh_key_pri_2 $ssh_key_pub_2 $DIR_INSTALL/root/.ssh/
  cd $DIR_INSTALL/root/.ssh
  ln -sf $ssh_key_pub_2 authorized_keys
  ln -sf $ssh_key_pri_2 $ssh_key_pri_1
  ln -sf $ssh_key_pub_2 $ssh_key_pub_1
  chmod 700 $DIR_INSTALL/root/.ssh
  chmod 600 $DIR_INSTALL/root/.ssh/*
fi

cat >"$DIR_INSTALL/root/.ssh/config"<<'EOF'
Host *
  StrictHostKeyChecking=no
EOF
}

setup_ssh_key
#-------------------------------------------------------------------------------

cd /
sync
umount $DIR_INSTALL