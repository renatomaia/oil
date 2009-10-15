local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Raiser = {}
function Raiser:raisenow()
	error{ "IDL:ExceptionRaiser/RaisedException:1.0",
		reason = "exception",
	}
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	orb:loadidl[[
		interface ExceptionRaiser {
			exception RaisedException {
				string reason;
			};
			void raisenow() raises (RaisedException);
		};
	]]
	Raiser.__type = "ExceptionRaiser"
end
orb:newservant(Raiser, "raiser")

orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init{ extraproxies = { "asynchronous", "protected" } }
checks = oil.dtests.checks

raiser = oil.dtests.resolve("Server", 2809, "raiser")
badobj = oil.dtests.resolve("", 0, "", nil, true, true)

if oil.dtests.flavor.corba then
	badobj = orb:narrow(badobj, "ExceptionRaiser")
end

raisers = {
	[raiser] = function(exception)
		checks:assert(exception[1], checks.equals("IDL:ExceptionRaiser/RaisedException:1.0", "wrong exception."))
		checks:assert(exception.reason, checks.equals("exception", "wrong exception field."))
	end,
	[badobj] = function(exception)
		if oil.dtests.flavor.corba then
			checks:assert(exception, checks.similar{"IDL:omg.org/CORBA/COMM_FAILURE:1.0"})
		elseif oil.dtests.flavor.ludo then
			checks:assert(exception, checks.match("connection refused$", "wrong exception."))
		end
	end,
}

for raiser, exchecker in pairs(raisers) do
	async = orb:newproxy(raiser, "asynchronous")
	prote = orb:newproxy(raiser, "protected")
	
	--
	-- pcall exception catch
	--
	-- synchronous call
	ok, exception = oil.pcall(raiser.raisenow, raiser)
	checks:assert(not ok, "exception was not raised.")
	exchecker(exception)
	-- asynchronous call
	future = async:raisenow()
	oil.sleep(.1); assert(future:ready())
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
			async.__exceptions = handler
		elseif case == 2 then
			orb:setexcatch(handler)
		elseif case == 3 then
			if not oil.dtests.flavor.corba then break end
			orb:setexcatch(handler, "ExceptionRaiser")
		end
		
		excount = 0
		-- synchronous call
		result = raiser:raisenow()
		checks:assert(excount, checks.is(1, "wrong number of raised exceptions."))
		checks:assert(result, checks.is(excount, "wrong operation result after exception catch."))
		-- asynchronous call
		future = async:raisenow()
		oil.sleep(.1); assert(future:ready())
		ok, exception = future:results()
		checks:assert(not ok, "exception was not raised.")
		exchecker(exception)
		result = future:evaluate()
		checks:assert(excount, checks.is(2, "wrong number of raised exceptions."))
		checks:assert(result, checks.is(excount, "wrong operation result after exception catch."))
		
		if case == 1 then
			raiser.__exceptions = nil
			async.__exceptions = nil
		elseif case == 2 then
			orb:setexcatch(nil)
		elseif case == 3 and oil.dtests.flavor.corba then
			orb:setexcatch(nil, "ExceptionRaiser")
		end
	end
	
	--
	-- protected proxy
	--
	ok, exception = prote:raisenow()
	checks:assert(not ok, "exception was not raised.")
	exchecker(exception)
end
--[Client]=====================================================================]

return template:newsuite()
