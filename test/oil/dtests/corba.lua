
local error = error

local oil = require "oil"

module "oil.dtests"

timeout = 10
querytime = .5

Reference = "corbaloc::%s:%d/%s"
function resolve(proc, port, objkey, nowait, nonarrow)
	local proxy = oil.newproxy(
		Reference:format(hosts[proc] or proc, port, objkey),
		oil.corba.idl.object)
	if nowait then return nonarrow and proxy or oil.narrow(proxy) end
	for i = 1, timeout/querytime do
		if not proxy:_non_existent() then
			return nonarrow and proxy or oil.narrow(proxy)
		end
		oil.sleep(querytime)
	end
	error("object not found")
end
