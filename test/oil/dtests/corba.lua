local _G = require "_G"
local assert = _G.assert
local error = _G.error
local pcall = _G.pcall

local oil = require "oil"
local sleep = oil.sleep

local idl = require "oil.corba.idl"
local CORBA_Object = idl.object

local giop = require "oil.corba.giop"
local CORBA_Transient = giop.SystemExceptionIDs.TRANSIENT

local _ENV = require "oil.dtests"; if _VERSION == "Lua 5.1" then setfenv(1, _ENV) end

timeout = 3
querytime = .5

Reference = "corbaloc::%s:%d/%s"
function resolve(proc, port, objkey, kind, nowait, nonarrow)
	assert(orb ~= nil, "DTest not initialized")
	local proxy = orb:newproxy(
		Reference:format(hosts[proc] or proc, port, objkey),
		kind,
		CORBA_Object)
	if nowait then return nonarrow and proxy or orb:narrow(proxy) end
	for i = 1, timeout/querytime do
		local ok, result = pcall(proxy._non_existent, proxy)
		if ok then
			if not result then
				return nonarrow and proxy or orb:narrow(proxy)
			end
		elseif result._repid ~= CORBA_Transient then
			error(result)
		end
		sleep(querytime)
	end
	error("object not found")
end
