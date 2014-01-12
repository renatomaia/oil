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
worker = oil.dtests.resolve("Server", 2809, "worker")

-- synchronous call
start = oil.time()
result = worker:work(.1)
assert(oil.time() - start > .1, "synchronous operation didn't wait.")
assert(worker:count() == 1, "wrong number of performed operations.")
assert(result == .1, "wrong results.")

-- asynchronous call
async = oil.dtests.orb:newproxy(worker, "asynchronous")
async:work(0)
future = async:work(.2)
oil.sleep(.1)
assert(not future:ready(), "unfinished operation returned.")
oil.sleep(.2)
assert(future:ready(), "finished operation was not ready.")
ok, result = future:results()
assert(ok == true, "operation results indicated a unexpected error.")
assert(result == .2, "wrong results.")
assert(future:evaluate() == .2, "wrong results.")
assert(worker:count() == 3, "wrong number of performed operations.")

-- asynchronous call, but waiting for results
async:work(0)
future = async:work(.3)
oil.sleep(.1)
start = oil.time()
assert(future:evaluate() == .3, "wrong results.")
assert(oil.time() - start > .1, "results on unfinished operation didn't wait.")
assert(worker:count() == 5, "wrong number of performed operations.")
ok, result = future:results()
assert(ok == true, "operation results indicated a unexpected error.")
assert(result == .3, "wrong results.")

-- protected synchronous call
prot = oil.dtests.orb:newproxy(worker, "protected")
start = oil.time()
ok, result = prot:work(.1)
assert(oil.time() - start > .1, "synchronous operation didn't wait.")
assert(worker:count() == 6, "wrong number of performed operations.")
assert(ok == true, "operation results does not indicates success")
assert(result == .1, "wrong results.")

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
