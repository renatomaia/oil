require "oil"

local Viewer = require "loop.debug.Viewer"

oil.assemble "corba.typed.cooperative.base"

--------------------------------------------------------------------------------

local interceptor = {}

--------------------------------------------------------------------------------

local send_context_idl = oil.loadidl [[
	struct ServerInfo {
		long memory;
		string stack;
	};
]]
function interceptor:sendrequest(request)
	print("intercepting request to "..request.operation.."("..Viewer:tostring(unpack(request, 1, request.count))..")")
	local encoder = oil.newencoder()
	encoder:put({
		memory = gcinfo(),
		stack = debug.traceback("client intercepted"),
	}, send_context_idl)
	request.service_context = {
		{
			context_id = 1234,
			context_data = encoder:getdata()
		}
	}
end

--------------------------------------------------------------------------------

local receive_context_idl = oil.loadidl [[
	struct ClientInfo {
		double start;
		double ending;
	};
]]
function interceptor:receivereply(reply)
	print("intercepting reply of opreation "..reply.operation)
	print("\tsuccess:", reply.success)
	print("\tresults:", Viewer:tostring(unpack(reply, 1, reply.count)))
	for _, context in ipairs(reply.service_context) do
		if context.context_id == 4321 then
			local decoder = oil.newdecoder(context.context_data)
			local result = decoder:get(receive_context_idl)
			print("\ttime:", result.ending - result.start)
			return
		end
	end
	io.stderr:write("context 4321 not found! Canceling ...\n")
	reply.success = false
	reply.count = 1
	reply[1] = oil.newexcept{ "ACCESS_DENIED" }
end

--------------------------------------------------------------------------------

oil.setclientinterceptor(interceptor)

--------------------------------------------------------------------------------

if select("#", ...) == 0 then
	io.stderr:write "usage: lua client.lua <time of client 1>, <time of client 2>, ..."
	os.exit(-1)
end
local arg = {...}

--------------------------------------------------------------------------------

oil.main(function()
	local proxy = oil.newproxy(assert(oil.readfrom("server.ior")))
	
	local function showprogress(id, time)
		print(id, "about to request work for "..time.." seconds")
		if proxy:do_something_for(time)
			then print(id, "result received successfully")
			else print(id, "got an unexpected result")
		end
	end
	
	for id, time in ipairs(arg) do
		oil.newthread(showprogress, id, tonumber(time))
	end
end)
