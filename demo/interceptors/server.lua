require "socket"
require "oil"                                   -- Load OiL package

local Viewer = require "loop.debug.Viewer"

--------------------------------------------------------------------------------

local interceptor = {}

--------------------------------------------------------------------------------

local receive_context_idl = oil.loadidl [[
	struct ServerInfo {
		long memory;
		string stack;
	};
]]
function interceptor:receiverequest(request)
	request.start_time = socket.gettime()
	print("intercepting request to "..request.operation.."("..Viewer:tostring(unpack(request, 1, request.count))..")")
	for _, context in ipairs(request.service_context) do
		if context.context_id == 1234 then
			local decoder = oil.newdecoder(context.context_data)
			local result = decoder:get(receive_context_idl)
			print("\tmemory:", result.memory)
			print("\tstack:" , result.stack)
			return
		end
	end
	io.stderr:write("context 1234 not found! Canceling...\n")
	request.success = false
	request.count = 1
	request[1] = oil.newexcept{ "BAD_OPERATION", minor_code_value = 0 }
end

--------------------------------------------------------------------------------

local send_context_idl = oil.loadidl [[
	struct ClientInfo {
		double start;
		double ending;
	};
]]
function interceptor:sendreply(reply)
	print("intercepting reply of opreation "..reply.operation)
	print("\tsuccess:", reply.success)
	print("\tresults:", Viewer:tostring(unpack(reply, 1, reply.count)))
	local encoder = oil.newencoder()
	encoder:put({
		start = reply.start_time,
		ending = socket.gettime(),
	}, send_context_idl)
	reply.service_context = {
		{
			context_id = 4321,
			context_data = encoder:getdata()
		}
	}
end

--------------------------------------------------------------------------------

oil.setserverinterceptor(interceptor)

--------------------------------------------------------------------------------

oil.main(function()
	oil.loadidl [[
		module Concurrency {
			interface Server {
				boolean do_something_for(in double seconds);
			};
		};
	]]
	
	local server_impl = {}
	function server_impl:do_something_for(seconds)
		oil.sleep(seconds)
		return true
	end
	
	local server = oil.newobject(server_impl, "Concurrency::Server")
	
	assert(oil.writeto("server.ior", oil.tostring(server)))
	
	oil.run()
end)
