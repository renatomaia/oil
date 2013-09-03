local _G = require "_G"
local assert = _G.assert
local error = _G.error
local pcall = _G.pcall
local type  = _G.type

require "oil.dtests"

oil.dtests.timeout = 3
oil.dtests.querytime = .5

oil.dtests.Reference = "return %q,%q,%d\0"
function oil.dtests.resolve(proc, port, objkey, kind, nowait)
	assert(orb ~= nil, "DTest not initialized")
	local proxy = orb:newproxy(
		oil.dtests.Reference:format(objkey,
		oil.dtests.hosts[proc] or proc,
		port))
	if nowait then return proxy end
	for i = 1, oil.dtests.timeout/oil.dtests.querytime do
		local success, errmsg = pcall(proxy._non_existent, proxy)
		if success or (type(errmsg) == "table" and errmsg.error == "badobjimpl")
		then -- '_non_existent' may not provided but such object exists ;-)
			return proxy
		elseif type(errmsg) ~= "table" or errmsg.error ~= "badconnect" then
			error(errmsg)
		end
		oil.sleep(oil.dtests.querytime)
	end
	error("object not found")
end
