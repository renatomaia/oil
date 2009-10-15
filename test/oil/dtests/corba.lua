
local assert = assert
local error = error

local oil = require "oil"
require "oil.dtests"
module "oil.dtests"

timeout = 3
querytime = .5

Reference = "corbaloc::%s:%d/%s"
function resolve(proc, port, objkey, kind, nowait, nonarrow)
	assert(orb ~= nil, "DTest not initialized")
	local proxy = orb:newproxy(
		Reference:format(hosts[proc] or proc, port, objkey),
		kind,
		oil.corba.idl.object)
	if nowait then return nonarrow and proxy or orb:narrow(proxy) end
	for i = 1, timeout/querytime do
		if not proxy:_non_existent() then
			return nonarrow and proxy or orb:narrow(proxy)
		end
		oil.sleep(querytime)
	end
	error("object not found")
end
