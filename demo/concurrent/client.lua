require "oil"

oil.verbose:level(5)
loop.thread.Scheduler.verbose:flag("threads", true)

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
local ior = oil.readIOR("proxy.ior")
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
	oil.myScheduler.threads:register(coroutine.create(function()
		print(id, "about to request work for "..time.." seconds")
		if proxy:request_work_for(tonumber(time))
			then print(id, "result received successfully")
			else print(id, "got an unexpected result")
		end
	end))
end

oil.myScheduler.control:run()
