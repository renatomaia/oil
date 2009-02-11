package.loaded["oil.component"] = require "loop.component.wrapped"
package.loaded["oil.port"]      = require "loop.component.intercepted"
local Viewer                    = require "loop.debug.Viewer"
local oil                       = require "oil"

oil.main(function()
	local orb = oil.init{ flavor = "cooperative;ludo" }
	
	-- create and register the server interceptor
	local viewer = Viewer{ maxdepth = 2 }
	local profiler = {}
	function profiler:receiverequest(request)
		request.start_time = socket.gettime()
		print("intercepting request to "..request.operation..
		      "("..viewer:tostring(unpack(request, 1, request.n))..")")
	end
	function profiler:sendreply(reply)
		print("intercepting reply of opreation "..reply.operation)
		print("\tsuccess:", reply.success)
		print("\tresults:", unpack(reply, 1, reply.n))
	end
	orb:setinterceptor(profiler, "server")
	
	-- create servant and write its reference
	local impl = {}
	function impl:do_something_for(seconds)
		oil.sleep(seconds)
		return true
	end
	local servant = orb:newservant(impl)
	assert(oil.writeto("server.ref", servant))
	
	-- start processing requests
	orb:run()
end)
