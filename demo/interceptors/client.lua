package.loaded["oil.component"] = require "loop.component.wrapped"
package.loaded["oil.port"]      = require "loop.component.intercepted"
local Viewer                    = require "loop.debug.Viewer"
local oil                       = require "oil"

if select("#", ...) == 0 then
	io.stderr:write "usage: lua client.lua <time of client 1>, <time of client 2>, ..."
	os.exit(-1)
end
local arg = {...}

oil.main(function()
	local orb = oil.init{ flavor = "cooperative;corba.intercepted" }
	orb:loadidlfile("profiler.idl")
	
	local ClientInfo = assert(orb.types:lookup("Profiler::ClientInfo"))
	local ServerInfo = assert(orb.types:lookup("Profiler::ServerInfo"))
	local viewer = Viewer{ maxdepth = 2 }
	local profiler = {}
	function profiler:sendrequest(request)
		print("intercepting request to "..request.operation_name..
		      "("..viewer:tostring(unpack(request, 1, request.n))..")")
		local encoder = orb:newencoder()
		encoder:put({
			memory = collectgarbage("count"),
		}, ServerInfo)
		request.service_context = {
			{
				context_id = 1234,
				context_data = encoder:getdata()
			}
		}
	end
	function profiler:receivereply(reply, request)
		print("intercepting reply of opreation "..request.operation_name)
		print("\tsuccess:", reply.success)
		print("\tresults:", unpack(reply, 1, reply.n))
		for _, context in ipairs(reply.service_context) do
			if context.context_id == 4321 then
				local decoder = orb:newdecoder(context.context_data)
				local result = decoder:get(ClientInfo)
				print("\ttime:", result.ending - result.start)
				return
			end
		end
		io.stderr:write("context 4321 not found! Canceling ...\n")
		reply.cancel = true
		reply.success = false
		reply.n = 1
		reply[1] = orb:newexcept{ "NoProfiling", -- local exception, unknown to CORBA
			operation = operation
		}
	end
	orb:setinterceptor(profiler, "client")
	
	local server = orb:newproxy(assert(oil.readfrom("server.ior")))
	local function showprogress(id, time)
		print(id, "about to request work for "..time.." seconds")
		if server:do_something_for(time)
			then print(id, "result received successfully")
			else print(id, "got an unexpected result")
		end
	end
	for id, time in ipairs(arg) do
		oil.newthread(showprogress, id, tonumber(time))
	end
end)
