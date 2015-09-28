local Viewer = require "loop.debug.Viewer"
local oil = require "oil"
local cothread = require "cothread"

if select("#", ...) == 0 then
	io.stderr:write "usage: lua client.lua <time of client 1>, <time of client 2>, ..."
	os.exit(-1)
end
local arg = {...}

oil.main(function()
	local orb = oil.init{ flavor = "cooperative;ludo" }
	
	local viewer = Viewer{ maxdepth = 2 }
	local profiler = {}
	function profiler:sendrequest(request)
		print("intercepting request to "..request.operation..
		      "("..viewer:tostring(unpack(request, 1, request.n))..")")
	end
	function profiler:receivereply(reply, request)
		print("intercepting reply of opreation "..request.operation)
		print("\tsuccess:", reply.success)
		print("\tresults:", unpack(reply, 1, reply.n))
	end
	orb:setinterceptor(profiler, "client")
	
	local thread = cothread.running()
	local count = 0
	local server = orb:newproxy(assert(oil.readfrom("server.ref")))
	local function showprogress(id, time)
		print(id, "about to request work for "..time.." seconds")
		if server:do_something_for(time)
			then print(id, "result received successfully")
			else print(id, "got an unexpected result")
		end
		count = count+1
		if count == #arg then
			cothread.schedule(thread)
		end
	end
	for id, time in ipairs(arg) do
		oil.newthread(showprogress, id, tonumber(time))
	end
	
	cothread.suspend()
	orb:shutdown()
end)
