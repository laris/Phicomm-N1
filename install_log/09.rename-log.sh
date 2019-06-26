#/usr/bin/env bash
set -x

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

INSTALL_LOG="/boot/install_log"
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
cd ${INSTALL_LOG}/..
mv install_log install_log_SN_$(fw_printenv | grep serial= | cut -d "=" -f 2)_$(echo $(get_node_value 4) | sed 's/"//g')_$TIMESTAMP