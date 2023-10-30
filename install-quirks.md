### Tp-linki

##### wdr4300:
 - rev. 1.6: nie wiem jak zflashować bootloaderem, instrukcje z openWRT wiki nie działają.
   O ile nie zostanie zbrickowany, to można ``sysupgrade``'em flashować.

 - rev. 1.7: instrukcje z openWRT wiki działają, potrzeba serwera tftp na 192.168.0.66/24
   serve'ującego image nazwany ``wdr4300v1_tp_recovery.bin``. 

 - jeżeli nie da się wejść w tftp recovery, ale da się w openwrt recovery, to
   `mtd -r write openwrt*-squashfs-factory.bin firmware`

##### archer C7
 - idk, flashowałem ``sysupgrade``'em
