m = Map("talent", "Talent - Routers")

k = m:section(NamedSection, "key", "key", "Shared key", "The shared key that will be used to sign and verify tokens between routers")
k.addremove = true
k:option(TextValue, "key", "Key")

s = m:section(TypedSection, "router", "Routers", "Talent routers that are part of this network")
s.addremove = true
s.anonymous = true

s:option(Value, "name", "Name")
ipaddr = s:option(Value, "ipaddr", "IP address")
function ipaddr:validate(value)
    return luci.ip.checkip4(value)
end

return m
