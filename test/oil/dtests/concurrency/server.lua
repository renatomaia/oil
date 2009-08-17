local oil = require "oil"

oil.loadidl[[
	interface Server {
		void start(in double timeout);
		void complete();
	};
]]

oil.main(function()
	oil.init{ port = 2809 }
	local impl = {}
	function impl:start(timeout)
		if timeout < 0 and oil.tasks then
			self[#self+1] = oil.tasks.current
			oil.tasks:suspend()
		else
			oil.sleep(timeout)
		end
	end
	function impl:complete()
		local suspended = self[#self]
		if suspended then
			return oil.tasks:resume(suspended)
		end
	end
	oil.newservant(impl, "Server", "Server")
	oil.run()
end)
