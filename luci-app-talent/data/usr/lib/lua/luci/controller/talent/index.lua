module("luci.controller.talent.index", package.seeall)

local function talent_firewall_rules()
	local cursor = luci.model.uci.cursor()

	local talent_rules_set = {}

	cursor:foreach("talent", "firewall_rule", function(section)
		talent_rules_set[section.rule] = 1
	end)

	local results = {}
	cursor:foreach("firewall", "rule", function(section)
		if talent_rules_set[section["name"]] ~= nil then
			results[#results + 1] = section
		end
	end)

	return results
end

local function value_set(table)
	local set = {}
	for _, e in pairs(table) do set[e] = 1 end
	return set
end

-- TODO: Theoretically the "talent token" system can be intergrated with normal ubus sessions but that would take considerable work

local function compute_our_hmac(message)
	local key = luci.model.uci.cursor():get("talent", "key", "key")
	if key == nil then error("talent.key.key is nil :(") end
	return require("hmac").compute(key, message, require("sha2").sha256, 512)
end

-- This is a great idea
local function time()
	return luci.util.ubus("system", "info").localtime
end

local function create_talent_token(lifetime)
	local value = {
		valid_until = time() + lifetime
	}

	local hmac = compute_our_hmac(luci.jsonc.stringify(value))
	value["hmac"] = require("nixio").bin.b64encode(hmac)
	return luci.jsonc.stringify(value)
end

local function check_talent_token(token)
	local data = luci.jsonc.parse(token)
	if data == nil or type(data["hmac"]) ~= "string" then return nil end

	local their_hmac = require("nixio").bin.b64decode(data.hmac)
	data.hmac = nil
	local our_hmac = compute_our_hmac(luci.jsonc.stringify(data))
	if their_hmac ~= our_hmac then
		return nil
	end

	if data.valid_until < time() then
		return nil
	end

	return data
end

local function http_check_talent_token()
	local value = luci.http.formvalue("tt")
	if value ~= nil then return check_talent_token(value) end
	return nil
end

local function talent_is_authenticated()
	if http_check_talent_token() then
		return {read=1, write=1}
	end

	local _, _, sacl = luci.dispatcher.is_authenticated({
		methods = { "cookie:sysauth_https", "cookie:sysauth_http" }
	})

	if sacl and type(sacl["access-group"]) == "table" then
		-- TODO: Make our own access-group instead of just hijacking luci-app-firewall
		return value_set(sacl["access-group"]["luci-app-firewall"])
	end

	return {}
end

local function firewall_api_get_self()
	local enabled_count = 0
	local total_count = 0

	for _, section in ipairs(talent_firewall_rules()) do
		if section.enabled ~= "0" then
			enabled_count = enabled_count + 1
		end
		total_count = total_count + 1
	end

	local state
	if enabled_count == total_count then
		state = "enabled"
	elseif enabled_count > 0 then
		state = "partial"
	else
		state = "disabled"
	end

	return {
		status = "success",
		data = { state = state }
	}
end

local function firewall_api_post_self()
	local POSSIBLE_INPUTS = {
		enabled = true,
		enable = true,
		disabled = false,
		disable = false
	}

	local new_state = POSSIBLE_INPUTS[luci.http.formvalue("state")]
	if new_state == nil then
		luci.http.status(401, "Bad Request")
		return {
			status = "error",
			message = "Missing or invalid 'state' parameter",
		}
	end

	local new_enabled
	if new_state then new_enabled = true else new_enabled = false end

	local cursor = luci.model.uci.cursor()
	for _, section in pairs(talent_firewall_rules()) do
		cursor:set("firewall", section[".name"], "enabled", new_enabled)
	end
	cursor:save()
	cursor:commit()
	cursor:apply(false)

	return { status = "success" }
end

local function forbidden()
	luci.http.status(403, "Forbidden")
	return { status = "error", message = "Forbidden" }
end

api = {}
function api:firewall()
	local method = luci.http.getenv("REQUEST_METHOD")

	if method == "GET" then
		if not talent_is_authenticated()["read"] then
			return forbidden()
		end

		return firewall_api_get_self()
	elseif method == "POST" then
		if not talent_is_authenticated()["write"] then
			return forbidden()
		end

		return firewall_api_post_self()
	else
		luci.http.status(405, "Method Not Allowed")
		return { status = "error", message = "Unsupported method" }
	end
end

function api:routers()
	-- TODO: Store the permissions in the token so that read-only users can access this endpoint
	if talent_is_authenticated()["read"] and talent_is_authenticated()["write"] then
		local results = {}
		local cursor = luci.model.uci.cursor()

		cursor:foreach("talent", "router", function(section)
			results[#results + 1] = {
				name = section["name"],
				address = section["ipaddr"]
			}
		end)

		return {
			token = create_talent_token(60 * 60 * 24),
			routers = results
		}
	else
		return forbidden()
	end
end

function api:ping()
    luci.http.prepare_content("text/html")
    luci.http.write("<h1>OK</h1>")
end

function call_api(fun)
	luci.http.header("Access-Control-Allow-Origin", "*")
    local value = api[fun]()
    if value ~= nil then
        luci.http.prepare_content("application/json")
        luci.http.write_json(value)
    end
end

function index()
	entry({ "admin", "talent" }, firstchild(), "Talent", 10)

	entry({ "admin", "talent", "settings" }, firstchild(), "Settings", 1)

	entry({ "admin", "talent", "settings", "routers" }, cbi("talent/routers"), "Routers", 1)
	entry({ "admin", "talent", "settings", "rules" }, cbi("talent/rules"), "Firewall rules", 1)

	entry({ "admin", "talent", "firewall_control" }, template("talent/firewall_control"), "Firewall control", 3)

	function api_entry(path, fun)
		local e = entry(path, call("call_api", fun), "API", 53)
		e.cors = true
		e.dependent = false
		return e
	end

	api_entry({ "talent", "firewall" }, "firewall")
	api_entry({ "talent", "routers" }, "routers")
	api_entry({ "talent", "ping" }, "ping")
end
