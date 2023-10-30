### Tp-linki

##### Generalne wnioski
Nie jestem pewien poniższego faktu, ale bardzo możliwe iż jest on prawdziwy.

W zależności od tego, czy na openwrt wiki każą wyciągnąć z factory image'a
bootloader i dokleić na początek tego z openwrt, albo tftp recovery będzie
działać po pierwszej instalacji, albo będzie wchodziło do recovery mode'a
openwrt. Warto patrzeć, czy coś stoi na 192.168.1.1 i na logi serwera tftp.

##### Wchodzenie w recovery mode
Przeważnie jest to kwestia wciśnięcia na jakąś sekundę przycisku "WPS/reset",
gdy po reboocie któryś LED na ruterze zaczyna migać, winien wtedy przyspieszyć
to miganie. Alternatywnie, należy zacząć przytrzymywać na jakieś 10s
"WPS/reset" zanim ruter się włączy.
