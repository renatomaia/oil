local Suite = require "loop.test.Suite"
local Template = require"oil.dtests.Template"
local test = Template{"Client"} -- master process name

Server = [=====================================================================[
if oil.dtests.flavor.corba then
	oil.loadidl[[
		exception RaisedException {
			string reason;
		};
		interface ExceptionRaiser {
			void raisenow() raises (RaisedException);
		};
	]]
end

Raiser = {}
function Raiser:raisenow()
	error{ "IDL:RaisedException:1.0",
		reason = "exception",
	}
end

oil.init{ port = 2809 }
oil.newservant(Raiser, "ExceptionRaiser", "raiser")
oil.run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

raiser = oil.dtests.resolve("Server", 2809, "raiser")
badobj = oil.dtests.resolve("", 0, "", true, true)

if oil.dtests.flavor.corba then
	oil.loadidl[[
		exception RaisedException {
			string reason;
		};
		interface ExceptionRaiser {
			void raisenow() raises (RaisedException);
		};
	]]
	badobj = oil.narrow(badobj, "ExceptionRaiser")
end

raisers = {
	[raiser] = function(exception)
		checks:assert(exception[1], checks.equals("IDL:RaisedException:1.0", "wrong exception."))
		checks:assert(exception.reason, checks.equals("exception", "wrong exception field."))
	end,
	[badobj] = function(exception)
		if oil.dtests.flavor.corba then
			checks:assert(exception[1], checks.equals("IDL:omg.org/CORBA/COMM_FAILURE:1.0", "wrong exception."))
		elseif oil.dtests.flavor.ludo then
			checks:assert(exception, checks.match("connection refused$", "wrong exception."))
		end
	end,
}

for raiser, exchecker in pairs(raisers) do
	--
	-- pcall exception catch
	--
	-- synchronous call
	ok, exception = oil.pcall(raiser.raisenow, raiser)
	checks:assert(not ok, "exception was not raised.")
	exchecker(exception)
	-- asynchronous call
	future = raiser.__deferred:raisenow()
	oil.sleep(1); assert(future:ready())
	ok, exception = future:results()
	checks:assert(not ok, "exception was not raised.")
	exchecker(exception)
	ok, exception = oil.pcall(future.evaluate, future)
	checks:assert(not ok, "exception was not raised.")
	exchecker(exception)

	--
	-- exception handler callback
	--
	function handler(self, exception, operation)
		exchecker(exception)
		if oil.dtests.flavor.corba then
			operation = operation.name
			checks:assert(operation, checks.equals("raisenow", "wrong operation that raised exception."))
		end
		excount = excount + 1
		return excount
	end
	for case = 1, 3 do
		if case == 1 then
			raiser.__exceptions = handler
			raiser.__deferred.__exceptions = handler
		elseif case == 2 then
			oil.setexcatch(handler)
		elseif case == 3 then
			if not oil.dtests.flavor.corba then break end
			oil.setexcatch(handler, "ExceptionRaiser")
		end
		
		excount = 0
		-- synchronous call
		result = raiser:raisenow()
		checks:assert(excount, checks.is(1, "wrong number of raised exceptions."))
		checks:assert(result, checks.is(excount, "wrong operation result after exception catch."))
		-- asynchronous call
		future = raiser.__deferred:raisenow()
		oil.sleep(1); assert(future:ready())
		ok, exception = future:results()
		checks:assert(not ok, "exception was not raised.")
		exchecker(exception)
		result = future:evaluate()
		checks:assert(excount, checks.is(2, "wrong number of raised exceptions."))
		checks:assert(result, checks.is(excount, "wrong operation result after exception catch."))
		
		if case == 1 then
			raiser.__exceptions = nil
			raiser.__deferred.__exceptions = nil
		elseif case == 2 then
			oil.setexcatch(nil)
		elseif case == 3 and oil.dtests.flavor.corba then
			oil.setexcatch(nil, "ExceptionRaiser")
		end
	end
	
	--
	-- protected proxy
	--
	ok, exception = raiser.__try:raisenow()
	checks:assert(not ok, "exception was not raised.")
	exchecker(exception)
end
--[Client]=====================================================================]

return Suite{
	CoCORBA = test(),
	CoServerCORBA = test{
		Client = { flavor = "corba;typed;base" },
	},
	CoClientCORBA = test{
		Server = { flavor = "corba;typed;base" },
	},
	CORBA = test{
		Server = { flavor = "corba;typed;base" },
		Client = { flavor = "corba;typed;base" },
	},
	CoLuDO = test{
		Server = { flavor = "ludo;cooperative;base" },
		Client = { flavor = "ludo;cooperative;base" },
	},
	CoServerLuDO = test{
		Server = { flavor = "ludo;cooperative;base" },
		Client = { flavor = "ludo;base"             },
	},
	CoClientLuDO = test{
		Server = { flavor = "ludo;base"             },
		Client = { flavor = "ludo;cooperative;base" },
	},
	LuDO = test{
		Server = { flavor = "ludo;base" },
		Client = { flavor = "ludo;base" },
	},
}
