
## 00.u-boot help
```
gxl_p230_v1#help
?       - alias for 'help'
aml_sysrecovery- Burning with amlogic format package from partition sysrecovery
amlmmc  - AMLMMC sub system
autoscr - run script from memory
base    - print or set address offset
bcb     - bcb
bmp     - manipulate BMP image data
booti   - boot arm64 Linux Image image from memory
bootm   - boot application image from memory
bootp   - boot image via network using BOOTP/TFTP protocol
cbusreg - cbus register read/write
chipid  - Print Chip ID
clkmsr  - Amlogic measure clock
cmp     - memory compare
cp      - memory copy
crc32   - checksum calculation
cvbs    - CVBS sub-system
dcache  - enable or disable data cache
defenv_reserv- reserve some specified envs after defaulting env
dhcp    - boot image via network using DHCP/TFTP protocol
echo    - echo args to console
efuse   - efuse commands
efuse_user- efuse user space read write ops
emmc    - EMMC sub system
env     - environment handling commands
exit    - exit script
ext4load- load binary file from a Ext4 filesystem
ext4ls  - list files in a directory (default /)
ext4size- determine a file's size
false   - do nothing, unsuccessfully
fastboot- use USB Fastboot protocol
fatinfo - print information about filesystem
fatload - load binary file from a dos filesystem
fatls   - list files in a directory (default /)
fatsize - determine a file's size
fdt     - flattened device tree utility commands
forceupdate- forceupdate
get_rebootmode- get reboot mode
get_valid_slot- get_valid_slot
go      - start application at address 'addr'
gpio    - query and control gpio pins
hdmitx  - HDMITX sub-system
help    - print command description/usage
i2c     - I2C sub-system
icache  - enable or disable instruction cache
imgread - Read the image from internal flash with actual size
itest   - return true/false on integer compare
jtagoff - disable jtag
jtagon  - enable jtag
keyman  - Unify key ops interfaces based dts cfg
keyunify- key unify sub-system
loop    - infinite loop on address range
macreg  - ethernet mac register read/write/dump
md      - memory display
mm      - memory modify (auto-incrementing address)
mmc     - MMC sub system
mmcinfo - display MMC info
mw      - memory write (fill)
mwm     - mw mask function
nm      - memory modify (constant address)
open_scp_log- print SCP messgage
osd     - osd sub-system
phyreg  - ethernet phy register read/write/dump
ping    - send ICMP ECHO_REQUEST to network host
printenv- print environment variables
query   - SoC query commands
rarpboot- boot image via network using RARP/TFTP protocol
read_temp- cpu temp-system
reboot  - set reboot mode and reboot system
reset   - Perform RESET of the CPU
rsvmem  - reserve memory
run     - run commands in an environment variable
saradc  - saradc sub-system
saradc_12bit- saradc sub-system
saveenv - save environment variables to persistent storage
sdc_burn- Burning with amlogic format package in sdmmc
sdc_update- Burning a partition with image file in sdmmc card
set_active_slot- set_active_slot
set_trim_base- cpu temp-system
set_usb_boot- set usb boot mode
setenv  - set environment variables
showvar - print local hushshell variables
silent  - silent
sleep   - delay execution for some time
store   - STORE sub-system
systemoff- system off
temp_triming- cpu temp-system
test    - minimal test like /bin/sh
tftpboot- boot image via network using TFTP protocol
true    - do nothing, successfully
unpackimg- un pack logo image into pictures
update  - Enter v2 usbburning mode
usb     - USB sub-system
usb_burn- Burning with amlogic format package in usb
usb_update- Burning a partition with image file in usb host
usbboot - boot from USB device
version - print monitor, compiler and linker version
vout    - VOUT sub-system
vpp     - vpp sub-system
vpu     - vpu sub-system
wipeisb - wipeisb
write_trim- cpu temp-system
write_version- cpu temp-system
gxl_p230_v1#
```

## 01.u-boot version, U-Boot 2015.01-00010-gfe36fb9-dirty (Mar 17 2018 - 12:20:04)
```
gxl_p230_v1#version
U-Boot 2015.01-00010-gfe36fb9-dirty (Mar 17 2018 - 12:20:04)
aarch64-linux-gnu-gcc (Ubuntu/Linaro 4.9.3-13ubuntu2) 4.9.3
GNU ld (GNU Binutils for Ubuntu) 2.26.1
```

## 02.u-boot saveenv, hardcode offset, size 64KiB
* hardcode offset 
```
gxl_p230_v1#saveenv
Saving Environment to aml-storage...
mmc env offset: 0x27400000
Writing to MMC(1)... done
```

* env size
```
gxl_p230_v1#printenv (end of stdout)
Environment size: 6028/65532 bytes
```
