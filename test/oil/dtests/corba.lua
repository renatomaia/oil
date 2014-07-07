local _G = require "_G"
local assert = _G.assert
local error = _G.error
local xpcall = _G.xpcall

local debug = require "debug"
local traceback = debug.traceback

local oil = require "oil"
local sleep = oil.sleep

local idl = require "oil.corba.idl"
local CORBA_Object = idl.object

local giop = require "oil.corba.giop"
local CORBA_Transient = giop.SystemExceptionIDs.TRANSIENT

local _ENV = require "oil.dtests"

if _G._VERSION=="Lua 5.1" then _G.setfenv(1,_ENV) end -- Lua 5.1 compatibility

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
		local ok, result = xpcall(proxy._non_existent, traceback, proxy)
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
