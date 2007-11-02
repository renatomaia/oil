
local error = error
local type  = type

local oil = require "oil"

module "oil.dtests"

timeout = 10
querytime = .5

local LuDORef = "%s@%s:%d"
function getbyinfo(proc, port, objkey)
	local proxy = oil.newproxy(LuDORef:format(objkey, hosts[proc], port))
	for i = 1, timeout/querytime do
		local success, errmsg = oil.pcall(proxy._non_existent, proxy)
		if
			not success and
			type(errmsg) == "table" and
			errmsg.reason == "noimplement"
		then -- op '_non_existent' is not provided by such object exists ;-)
			return proxy
		end
		oil.sleep(querytime)
	end
	error("object not found")
end
