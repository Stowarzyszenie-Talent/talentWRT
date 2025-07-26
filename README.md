# Talent's openWRT config and utils

This repo contains a uci "template" for openWRT, which is meant to be applied
to Stowarzyszenie Talent's TP-link routers.
 
An ``init`` script is provided for applying the template to a fresh (!) openWRT
router. If a device already has the desired system, but has some leftover
configuration, you can run something like ``firstboot && reboot now``.

## APK/OPKG issues
OpenWRT should migrate to the APK (Alpine Linux) package manager in the next (2025?) release.
It already happened in snapshots, but has yet to arrive in a release.

So if an old router is used, one needs to either update it or
revert to commit `76bfb0f`.

##### TODO: support both opkg and apk.

## Additional setup for lo3

- on computers that is supposed to access the firewall ui, exceptions for
 self-signed certificates need to be created for **all** routers (visiting
 the sites and "accepting the risk" is enough).
- the "central" router needs to be configured to know about other ones in Talent
 -> settings -> routers
- all routers need to have the same "talent key", which can be seen in Talent
 -> settings
