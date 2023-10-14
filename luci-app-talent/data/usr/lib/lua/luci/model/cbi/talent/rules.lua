m = Map("talent", "Talent - Toggleable firewall rules")

available = {}
require("luci.model.uci").cursor():foreach("firewall", "rule", function(section)
    available[#available + 1] = section.name
end)

rs = m:section(TypedSection, "firewall_rule", "Firewall rules", "Rules that are part of the toggleable talent firewall")
rs.addremove = true
rs.anonymous = true

local rule = rs:option(ListValue, "rule", "Rule")
for _, name in ipairs(available) do rule:value(name) end

return m
