cd /boot; cp -r install_log.orig install_log; cd install_log; ./00.create-emmc-partition.sh 2>&1 | tee 00.log ; ./01.install-armbian-emmc.sh 2>&1 | tee 01.log ; ./09.rename-log.sh ; sync; reboot
