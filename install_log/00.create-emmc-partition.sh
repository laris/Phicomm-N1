#!/usr/bin/env bash
set -x

# ctr-c to stop uboot
# setenv start_usb_autoscript "if fatload usb 0 1020000 s905_autoscript; then autoscr 1020000; fi; if fatload usb 1 1020000 s905_autoscript; then autoscr 1020000; fi; if fatload usb 2 1020000 s905_autoscript; then autoscr 1020000; fi; if fatload usb 3 1020000 s905_autoscript; then autoscr 1020000; fi;"
# usb start; run start_usb_autoscript

#mkdir -p /boot/install_log
#put 00*.sh 01*.sh 09*.sh into install_log
#00.create-emmc-partition.sh
#01.install-armbian-emmc.sh
#sh -x 00.create-emmc-partition.sh 2>&1 | tee 00.log
#sh -x 01.install-armbian-emmc.sh 2>&1 | tee 01.log
#sh -x 09.rename-log.sh 2>&1 | tee 09.log

DEV_EMMC=/dev/mmcblk1
PART_ROOT=${DEV_EMMC}p1
#umount $DIR_INSTALL
# --------------------------------------------------
if grep -q $PART_ROOT /proc/mounts ; then
    echo "Unmounting ROOT partiton."
    umount -f $PART_ROOT
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
INSTALL_LOG="/boot/install_log"
mkdir -p ${INSTALL_LOG}
cd ${INSTALL_LOG}

backup_date_time()
{
  file=$1
  if [ -e ${file} ] ; then
    mv ${file} ${file}_${TIMESTAMP}
  fi
}

BIN_UBOOT="bin-uboot.bin"
BIN_RSVD="bin-rsvd.bin"
BIN_ENV="bin-env.bin"
PHY_OFFSET_RSVD_START="0x2400000"   # start 36 MiB
PHY_OFFSET_RSVD_LEN="0x480000"      # keep only 4.5 MiB
PHY_OFFSET_ENV_START="0x27400000"   # start 628 MiB
PHY_OFFSET_ENV_LEN="0x10000"        # keep only 64 KiB
PHY_OFFSET_EMMC_START_MIB="4"
PHY_OFFSET_EMMC_START_SEC=$(((${PHY_OFFSET_EMMC_START_MIB} * 1024 * 1024) / 512))
backup_date_time ${BIN_UBOOT}
backup_date_time ${BIN_RSVD}
backup_date_time ${BIN_ENV}

dd if=${DEV_EMMC} of=${BIN_UBOOT} bs=1M count=2
dd if=${DEV_EMMC} of=${BIN_RSVD}  bs=1K skip=$(($((${PHY_OFFSET_RSVD_START}))/1024)) count=$(($((${PHY_OFFSET_RSVD_LEN}))/1024))
dd if=${DEV_EMMC} of=${BIN_ENV}  bs=1K skip=$(($((${PHY_OFFSET_ENV_START}))/1024)) count=$(($((${PHY_OFFSET_ENV_LEN}))/1024))

parted -s ${DEV_EMMC} mklabel msdos
parted -s ${DEV_EMMC} unit s mkpart primary ext4 ${PHY_OFFSET_EMMC_START_SEC} 100%
# Restore U-boot (except the first 442 bytes, where partition table is stored.)
dd if=${BIN_UBOOT} of=${DEV_EMMC} conv=fsync bs=1 count=442
dd if=${BIN_UBOOT} of=${DEV_EMMC} conv=fsync bs=512 skip=1 seek=1
# Restore reserved 4.5 MiB
dd if=${BIN_RSVD}  of=${DEV_EMMC} conv=fsync bs=1K seek=$(($((${PHY_OFFSET_RSVD_START}))/1024))
# Restore env 64 KiB
dd if=${BIN_ENV}   of=${DEV_EMMC} conv=fsync bs=1K seek=$(($((${PHY_OFFSET_ENV_START}))/1024))
sync

# This method is used to convert byte offset in `${DEV_EMMC}` to block offset
# in `${DEV_EMMC}p1`.
gen_block_id() {
    # Block numbers are offseted by ${PHY_OFFSET_EMMC_START_MIB} 
    # since `${DEV_EMMC}p1` starts at ${PHY_OFFSET_EMMC_START_MIB} in `${DEV_EMMC}`.
    # Because we're using 4K blocks, the byte offsets are divided by 4K.
    PHY_OFFSET=$1
    expr $(((${PHY_OFFSET} - ${PHY_OFFSET_EMMC_START_MIB} * 1024 * 1024) / 4096))
}

# This method generates a sequence of block number in range [$1, $1 + $2).
# It's used for marking several reserved regions as bad blocks below.
gen_block_list(){
    PHY_OFFSET_START=$1
    PHY_OFFSET_LEN=$2
    seq $(gen_block_id ${PHY_OFFSET_START}) $(($(gen_block_id $((${PHY_OFFSET_START} + ${PHY_OFFSET_LEN}))) - 1))
}

BLOCK_RESERVE_LIST="reservedblks-list.log"

gen_block_list_file(){
  PART_NAME=$1
  PHY_OFFSET_START=$2
  PHY_OFFSET_LEN=$3
  echo "Marked blocks used by /dev/${PART_NAME} as bad."
  gen_block_list ${PHY_OFFSET_START} ${PHY_OFFSET_LEN} >> ${BLOCK_RESERVE_LIST}
}

backup_date_time ${BLOCK_RESERVE_LIST}

gen_block_list_file "reserved"  ${PHY_OFFSET_RSVD_START} ${PHY_OFFSET_RSVD_LEN}
gen_block_list_file "env"       ${PHY_OFFSET_ENV_START}  ${PHY_OFFSET_ENV_LEN}

# Let's see if a boot logo is to be installed.
#if [ -e /boot/n1-logo.img ]; then
#    dd if=/boot/n1-logo.img of=${DEV_EMMC} bs=1M seek=644
#    echo "Boot logo installed."
#    gen_block_list 0x28400000 0x800000 >> /tmp/reservedblks-list.log
#    echo "Marked blocks used by /dev/logo as bad."
#fi
#PHY_OFFSET_LOGO_START="0x28400000"
#PHY_OFFSET_LOGO_LEN="0x800000"
#gen_block_list_file "logo"       ${PHY_OFFSET_ENV_START}  ${PHY_OFFSET_ENV_LEN}

ROOTFS_LABEL="ROOT_EMMC"
# Format the partition. 
# -F force, -q quiet, -O ^64bit disable 64bit feature, -t ext4, 
# -m 0 reserved-blocks-percentage, -b block-size, -L label, -l bad-block-list.
mke2fs -F -q -O ^64bit -t ext4 -m 0 -b 4096 -L ${ROOTFS_LABEL} -l ${BLOCK_RESERVE_LIST} ${PART_ROOT}
e2fsck -n ${PART_ROOT}
# Flush changes (in case they were cached.).
sync
echo "Partition table (re-)initialized."

