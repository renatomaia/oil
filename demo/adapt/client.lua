if select("#", ...) == 0 then
	io.stderr:write "usage: lua client.lua <time of client 1>, <time of client 2>, ..."
	os.exit(-1)
end
local arg = {...}
--------------------------------------------------------------------------------
require "oil"
oil.main(function()
	local orb = oil.init()
	------------------------------------------------------------------------------
	local proxy = orb:newproxy(oil.readfrom("proxy.ior"))
	local padpt = orb:newproxy(oil.readfrom("proxyadaptor.ior"))
	local sadpt = orb:newproxy(oil.readfrom("serveradaptor.ior"))
	------------------------------------------------------------------------------
	local function showprogress(id, time)
		print(id, "about to request work for "..time.." seconds")
		local result = proxy:request_work_for(time)
		print(id, "got", result)
	end
	------------------------------------------------------------------------------
	local maximum = 0
	for id, time in ipairs(arg) do
		time = tonumber(time)
		oil.newthread(showprogress, id, time)
		maximum = math.max(time, maximum)
	end
	------------------------------------------------------------------------------
	local NewServerIDL = [[
		module Concurrent {
			interface Server {
				string do_something_for(in double seconds);
			};
		};
	]]
	local NewServerImpl = [[
		local server_impl = ...
		function server_impl:do_something_for(seconds)
			local message = "about to sleep for "..seconds.." seconds"
			oil.sleep(seconds)
			return message
		end
	]]

	local NewProxyIDL = [[
		module Concurrent {
			interface Proxy {
				string request_work_for(in double seconds);
			};
		};
	]]
	
	oil.sleep(maximum/2)
	orb:loadidl(NewProxyIDL)
	sadpt:update(NewServerIDL, NewServerImpl)
	padpt:update(NewServerIDL, "")
	padpt:update(NewProxyIDL, "")
	
	for id, time in ipairs(arg) do
		oil.newthread(showprogress, id, tonumber(time))
	end
	------------------------------------------------------------------------------
end)
