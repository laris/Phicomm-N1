PARTITION TABLE FORMAT OF PHICOMM N1
Carrot2018-12-02
https://isolated.site/2018/12/02/partition-table-format-of-phicomm-n1/

Found at offset 0x2400000 of /dev/mmcblk1:
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

Looks like it’s using format below:
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

Found some code about this: [Structure definition of `partitions` (and mask?)](https://github.com/codesnake/uboot-amlogic/blob/master/arch/arm/include/asm/arch-m6tvd/storage.h), [The partition table structure](https://github.com/codesnake/uboot-amlogic/blob/master/include/emmc_partitions.h).

I also found (presumbly) a BUG in checksum calculation: The checksum is actually calculated as `(uint32)(checksum-of-first-partition * number-of-partitions)`, any partition other than the first one is not taken into consideration. And as such, a simple equation for calculating the checksum would be `(uint32)(0xD9115133 * number_of_partitions)`.

I tried to move partition `logo` to somewhere more near to the beginning of the eMMC, but seems not work, not sure if the offset is also saved elsewhere.

The partition table itself is in `reserved`. Some code whose purpose is unclear is also in it.

The bootloader code starts from the second sector (512 byte) of `/dev/mmcblk1`. Which means the first sector is not used. And thus it’s possible to partition `/dev/mmcblk1` as MBR, as MBR only uses the first sector to store metadata. As long as the first partition starts after thoes special partitions (`bootloader`, `reserved`, but nothing else), the system still boots.