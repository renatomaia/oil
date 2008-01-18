local Suite = require "loop.test.Suite"
local Template = require"oil.dtests.Template"
local test = Template{"Client"} -- master process name

Server = [=====================================================================[
if oil.dtests.flavor.corba then
	oil.loadidl[[
		interface Worker {
			long count();
			void work(inout double timeout);
		};
	]]
end

Worker = { execs = 0 }
function Worker:count()
	return self.execs
end
function Worker:work(timeout)
	self.execs = self.execs + 1
	oil.sleep(timeout)
	return timeout
end

oil.init{ port = 2809 }
oil.newservant(Worker, "Worker", "worker")
oil.run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks
worker = oil.dtests.resolve("Server", 2809, "worker")

-- synchronous call
start = oil.time()
result = worker:work(1)
checks:assert(oil.time() - start > 1, "synchronous operation didn't wait.")
checks:assert(worker:count(), checks.is(1, "wrong number of performed operations."))
checks:assert(result, checks.is(1, "wrong results."))

-- asynchronous call
worker.__deferred:work(0)
future = worker.__deferred:work(2)
oil.sleep(1)
checks:assert(not future:ready(), "unfinished operation returned.")
oil.sleep(2)
checks:assert(future:ready(), "finished operation was not ready.")
ok, result = future:results()
checks:assert(ok == true, "operation results indicated a unexpected error.")
checks:assert(result, checks.is(2, "wrong results."))
checks:assert(future:evaluate(), checks.is(2, "wrong results."))
checks:assert(worker:count(), checks.is(3, "wrong number of performed operations."))

-- asynchronous call, but waiting for results
worker.__deferred:work(0)
future = worker.__deferred:work(3)
oil.sleep(1)
start = oil.time()
checks:assert(future:evaluate(), checks.is(3, "wrong results."))
checks:assert(oil.time() - start > 1, "results on unfinished operation didn't wait.")
checks:assert(worker:count(), checks.is(5, "wrong number of performed operations."))
ok, result = future:results()
checks:assert(ok == true, "operation results indicated a unexpected error.")
checks:assert(result, checks.is(3, "wrong results."))

-- protected synchronous call
start = oil.time()
ok, result = worker.__try:work(1)
checks:assert(oil.time() - start > 1, "synchronous operation didn't wait.")
checks:assert(worker:count(), checks.is(6, "wrong number of performed operations."))
checks:assert(ok == true, "operation results does not indicates success")
checks:assert(result, checks.is(1, "wrong results."))

--[Client]=====================================================================]

return Suite{
	LuDO = test{
		Server = { flavor = "ludo;base" },
		Client = { flavor = "ludo;base" },
	},
	CoServerLuDO = test{
		Server = { flavor = "ludo;cooperative;base" },
		Client = { flavor = "ludo;base"             },
	},
	CoClientLuDO = test{
		Server = { flavor = "ludo;base"             },
		Client = { flavor = "ludo;cooperative;base" },
	},
	CoLuDO = test{
		Server = { flavor = "ludo;cooperative;base" },
		Client = { flavor = "ludo;cooperative;base" },
	},
	
	CoCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
	CoServerCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;base" },
	},
	CoClientCORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
	CORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "corba;typed;base" },
	},
	
	IceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoServerIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoClientIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	CoIceptedCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	
	IceptedClientCORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoServerIceptedClientCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;base" },
	},
	CoIceptedClientCORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	IceptedClientCoCORBA = test{
		Server = { flavor = "corba;typed;cooperative;base" },
		Client = { flavor = "intercepted;corba;typed;cooperative;base" },
	},
	
	IceptedServerCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "corba;typed;base" },
	},
	CoIceptedServerCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;base" },
	},
	IceptedServerCoClientCORBA = test{
		Server = { flavor = "intercepted;corba;typed;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
	IceptedServerCoCORBA = test{
		Server = { flavor = "intercepted;corba;typed;cooperative;base" },
		Client = { flavor = "corba;typed;cooperative;base" },
	},
}
