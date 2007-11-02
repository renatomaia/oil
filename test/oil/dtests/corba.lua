
local error = error

local oil = require "oil"

module "oil.dtests"

timeout = 10
querytime = .5

local CORBALoc = "corbaloc::%s:%d/%s"
function getbyinfo(proc, port, objkey)
	local proxy = oil.newproxy(
		CORBALoc:format(hosts[proc], port, objkey),
		oil.corba.idl.object)
	for i = 1, timeout/querytime do
		if not proxy:_non_existent() then
			return oil.narrow(proxy)
		end
		oil.sleep(querytime)
	end
	error("object not found")
end
