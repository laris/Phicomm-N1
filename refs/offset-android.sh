#!/system/bin/sh
EMMC="/dev/mmcblk1"

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

die(){
    echo $*
    exit 1
}
print(){
    echo $1
    echo $2 $3
    echo -e "$(($2))\t$(($3))"
}
setup(){
    [ -e $1 ] && die "Error: file ${1} exist"
    loop_device=$(losetup --show -f "$EMMC" --offset "$(($2))" --sizelimit "$(($3))")
    if echo "$loop_device" |grep -Eq '/dev/.*loop[0-9]+'
    then
        ln -s "$loop_device" "$1"
    else
        die "Error: unable to assign loop device"
    fi
}
detach(){
    loop_device=$(readlink "$1")
    if echo "$loop_device" |grep -Eq '/dev/.*loop[0-9]+'
    then
        losetup -d "$loop_device"
    else
        die "Error: cannot find loop device for ${1}"
    fi
    losetup "$loop_device" 2>/dev/null |grep -Fq "$EMMC" && die "Cannot detach now. Maybe the loop device is mounted."
    rm "$1"
}
check_partname(){
    name_is_valid=false
    for part in $_all; do
        [ "$part" == "$1" ] && name_is_valid=true
    done
    $name_is_valid && return 0
    for part in $_all; do
        eval print '$_'"$part"
    done
    die "Error: partname is invaild"
}

if ! [ -e $EMMC ] ; then die "Error: emmc not found" ; fi
if [ "$1"  == "-d" ]; then
    check_partname "$2"
    detach "$2"
else
    check_partname "$1"
    eval setup '$_'"$1"
fi
