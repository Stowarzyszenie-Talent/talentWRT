## What is this?
A package for OpenWRT that adds two UIs to LuCI:

 - a simple interface for toggling the firewall, optionally on other devices remotely
 - an interface for configuring settings related to the one above

It was created for III LO in Gdynia, Poland.

### Some terms
 - opkg: the OpenWRT package manager, based on ipkg.
 - UCI: the Unified Configuration Interface, used by almost all of OpenWRT.
 - LuCI: OpenWRT's webUI written in Lua, mainly interacts with UCI.
 - fw: firewall.

### Useful links
 - [LuCI module development tutorial](https://github.com/openwrt/luci/wiki/ModulesHowTo)
 - [LuCI Lua API reference](https://openwrt.github.io/luci/api/index.html)
 - [LuCI JS API reference](https://openwrt.github.io/luci/jsapi/LuCI.html)


## Contents of this folder

#### build.sh
A simple script for packaging luci-app-talent into a .pkg file.
The .pkg format is supposedly similar to .deb (I don't think either of us bothered to check).

#### control/
Additional files for packaging. The ones worth mentioning are:

 - control: package metadata. Note that dependencies are comma-separated.
 - postinst-pkg: we clear the luci cache here and ensure that our UCI file exists.

#### data/
Files installed into the router's root directory.

#### data/*/model/cbi/talent/{routers,rules}.lua
The cbi is for neatly generating a UI for managing some uci settings.

In our case, we have UIs for all of our custom settings, which are:

- key: contains a string used for authenticating tokens across routers.
 It needs to be the same on all routers.
- router(s): a list with the names and addresses of routers which are to
 be shown in our UI
- firewall_rule(s): a list of fw rule names affected by our toggle.
 It is per-router, i.e. toggling router 1's fw from router 2 will
 enable/disable the rules specified in router 1's `talent.firewall_rule`.

#### data/*/controller/talent/index.lua
The HTTP endpoints added by the app are all defined here.

The UI stuff:

 - settings interface generated from the CBI mentioned above for managing those settings.
 - the one for fw toggling from the template file below.
 - the "ping" endpoint, which *should* just return "OK". No authentication.

The API endpoints allow an additional authentication method: the "talent token".
It is created by the `routers` endpoint which returns JSON object with the following structure:

 - `hmac`: a SHA256 [HMAC](https://en.wikipedia.org/wiki/HMAC) of this object serialized
   to JSON but without the `hmac` field
 - `valid_until`: a UNIX timestamp, if this field is greater than or equal to the current
   timestamp the token is no longer considered valid by the API

Passing a valid talent token via the `tt` query parameter grants read/write access
to talent API endpoints

The API endpoints, all returning JSON and with permissive CORS, are:

 - GET `routers`: returns a new talent token and a list of routers with both
     names and addresses (from the UCI).
 - GET `firewall`: On success returns `status`: "success" and an object in `data` which, as of writing
     this, contains only the field `state` set to one of "enabled", "partial", or "disabled", depending on
     the number of rules in `talent.firewall_rules` that are currently enabled.
 - POST `firewall`: sets the state of all rules in `talent.firewall_rules`
     to the request parameter "state" which must be either "enabled" or "disabled".

#### data/*/view/talent/firewall_control.htm
A view (template) for the firewall-toggling UI.
It works as follows:

1. GET the list of routers and a talent auth token from /cgi-bin/luci/talent/routers.
2. Populate the page with elements for all the routers.
3. Firewall status information is first fetched when a router element is added then
   once every 5 seconds and after state change requests.
4. The buttons for changing the fw state, upon being clicked, will POST the
   new state and talent auth token to /cgi-bin/luci/talent/firewall of the appropriate router.
   Then the new state will be queried, and if it has been successfully changed, a 3s cooldown will be enforced.
5. On error, an adequate message is displayed.

As we currently don't have a better way to both have https and make the
requests client-side, the user has to accept the other routers' certificates
manually. A hopefully descriptive enough message is therefore shown upon
failure to get a router's firewall state, asking the user to click a link to
that router's ping endpoint, accept the certificate and return.

This is also why we set the certificate's expiry date to 01.01.9999,
so once accepted, the certs should be ok forever.


### Common/possible issues
1. Firewall state get requests fail because of self-signed certs - accept them
   manually, just as the instructions in the UI tell you.
2. Firewall state get requests fail with 403 (forbidden) - check the routers'
   date and time, make sure that ntp is working correctly. Additionally, check
   whether the "talent key" is indeed the same across all routers.
3. The certificate expired - ensure that the uhttpd defaults have a long enough
   `uhttpd.defaults.days` and then `rm /etc/uhttpd.crt && service uhttpd restart`.
