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

local dtests = require "oil.dtests"

dtests.timeout = 3
dtests.querytime = .5

dtests.Reference = "corbaloc::%s:%d/%s"
function dtests.resolve(proc, port, objkey, kind, nowait, nonarrow)
	local orb = dtests.orb
	assert(orb ~= nil, "DTest not initialized")
	local proxy = orb:newproxy(
		dtests.Reference:format(dtests.hosts[proc] or proc, port, objkey),
		kind,
		CORBA_Object)
	if nowait then return nonarrow and proxy or orb:narrow(proxy) end
	for i = 1, dtests.timeout/dtests.querytime do
		local ok, result = pcall(proxy._non_existent, proxy)
		if ok then
			if not result then
				return nonarrow and proxy or orb:narrow(proxy)
			end
		elseif result._repid ~= CORBA_Transient then
			error(result)
		end
		sleep(dtests.querytime)
	end
	error("object not found")
end

return dtests