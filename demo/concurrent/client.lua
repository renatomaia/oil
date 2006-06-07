require "scheduler"
require "oil"

oil.verbose.output(io.open("client.log", "w"))
oil.verbose.level(4)
oil.verbose.flag("threads", true)

--------------------------------------------------------------------------------
if not arg then
	io.stderr:write "usage: lua client.lua <time of client 1>, <time of client 2>, ..."
	os.exit(-1)
end
--------------------------------------------------------------------------------
oil.loadidl [[
	module Concurrency {
		interface Proxy {
			boolean request_work_for(in double seconds);
		};
	};
]]
--------------------------------------------------------------------------------
local ior
local file = io.open("proxy.ior")
if file then
	ior = file:read("*a")
	file:close()
else
	print "unable to read IOR from file 'server.ior'"
	os.exit(1)
end
--------------------------------------------------------------------------------
local proxy = oil.newproxy(ior, "Concurrency::Proxy")
--------------------------------------------------------------------------------
local function showprogress(id, time)
	print(id, "about to request work for "..time.." seconds")
	if proxy:request_work_for(time)
		then print(id, "result received successfully")
		else print(id, "got an unexpected result")
	end
end
--------------------------------------------------------------------------------
for id, time in ipairs(arg) do
	scheduler.new(showprogress, id, tonumber(time))
end
scheduler.run()
