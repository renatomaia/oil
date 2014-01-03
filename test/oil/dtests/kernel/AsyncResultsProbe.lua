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

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	Worker.__type = orb:loadidl[[
		interface Worker {
			long count();
			void work(inout double timeout);
		};
	]]
end
orb:newservant(Worker, "worker")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
checks = oil.dtests.checks
worker = oil.dtests.resolve("Server", 2809, "worker")

-- synchronous call
oil.newthread(function()
	result = worker:work(.1)
	checks:assert(result, checks.is(.1, "wrong results."))
end)

-- asynchronous call
async = oil.dtests.orb:newproxy(worker, "asynchronous")
future = async:work(.1)
checks:assert(not future:ready(), "unfinished operation returned.")
oil.sleep(.2)
checks:assert(future:ready(), "finished operation was not ready.")
ok, result = future:results()
checks:assert(ok == true, "operation results indicated a unexpected error.")
checks:assert(result, checks.is(.1, "wrong results."))
checks:assert(future:evaluate(), checks.is(.1, "wrong results."))
checks:assert(worker:count(), checks.is(2, "wrong number of performed operations."))

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
