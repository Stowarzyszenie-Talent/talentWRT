## The uci templates

#### What are these?
A set of configuration templates for OpenWRT's Unified Configuration Interface.
These together with `../generate.py` allow mostly-automatic setups of our routers,
as the differences between groups of routers are really small.
The values in curly brackets are to be interpolated by `../generate.py` and
allow the script to account for those small variations.

These templates are predominantly human-readable.

#### wifi, wifi_nopass and wifi_withpass
These enable the disabled-by-default wifis, set their SSIDs and either make
the networks open or set the required psk for WPA2/WPA3.

#### system
Generic settings common to all routers: the hostname, timezone, https redirect,
custom certificate settings (the important one is "days", which allows for
making the cert valid for longer), ntp and some logging settings that luci
would set automatically when one enabled ntp.

#### st
This is the template applied to our routers used on camps, which are meant to
be simple APs. We disable wan as a precaution against someone plugging a cable
into the wrong port, disable dhcp, set the appropriate static ip settings
for our 10.0.0.0/8 network and point the ntp client towards our main server.

#### lo3
This one is for our routers in III LO in Gdynia, Poland. They aren't so simple
as the ST ones, as they need to have NAT in order to have a functioning
firewall. The template configures the WAN interface, enables an ntp server,
adds an upstream DNS server, configures `luci-app-talent` and adds a few
firewall rules:

 - allow https and ssh traffic on the wan interface for easier management
 - allow access to the local (school) network
 - allow traffic to Wyzwania (Talent's sio2), buz.info.pl and lo3.gdynia.pl
 - block all other traffic from LAN to WAN

Apparently, the first matching rule applies for every packet, so the blocking
one needs to be last.
If enabled in luci-app-talent, this firewall forbids generic internet traffic
and allows access to only a few sites.

NOTE: `set talent.key.key={TALENTKEY}`'s lack of quotes is intentional because
of `shlex.quote`.

TODO: maybe we should use a local DNS server instead?

#### lte
This one is quite specific, but it probably won't need to be extended, thus
we can assume we are working on a tp-link tl-mr6400, so with a wwan on qmi.
Its role is to provide a WAN connection over lte. As some/most carriers only
give out ipv6 addresses, we need 464xlat (somewhat) and DNS64 (we use
cloudflare's). The `ip6prefix` in 464xlat's config is for manually specifying
the well-known ipv4-in-ipv6 subnet for upstream NAT64. Our dns forwarding setup
*should* work regardless of the isp-provided ip addresses' family. For example,
when we are ipv6-only, 1.1.1.1 dns won't be reachable for anything more than
icmp (idk why), so dnsmasq will have to use the ipv6 (DNS64) one.

NOTE: one needs to manually setup the "QMI Cellular" interface with
ISP-provided information like the APN and auth credentials. Searching
"${carrier name} APN" usually suffices. As for "ipv4/ipv6/both", it might be
necessary to just try all of them and see what works.
