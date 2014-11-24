local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Worker = { execs = 0 }
function Worker:count()
	return self.execs
end
function Worker:work(timeout)
	self.execs = self.execs + 1
	oil.sleep(timeout)
	return timeout
end
function Worker:shutdown()
	orb:shutdown()
end

while true do
	orb = oil.dtests.init{ port = 2809 }
	if oil.dtests.flavor.corba then
		Worker.__type = orb:loadidl[[
			interface Worker {
				long count();
				void work(inout double timeout);
				void shutdown();
			};
		]]
	end
	orb:newservant(Worker, "worker")
	orb:run()
end
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
worker = oil.dtests.resolve("Server", 2809, "worker")

assert(worker:work(0) == 0)
assert(worker:count() == 1)

worker:shutdown()

oil.sleep(1)

assert(worker:work(0) == 0)
assert(worker:count() == 2)

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
