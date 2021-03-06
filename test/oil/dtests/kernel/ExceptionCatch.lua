local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Raiser = {}
function Raiser:raisenow()
	error{ _repid = "IDL:ExceptionRaiser/RaisedException:1.0",
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
orb = oil.dtests.init()
checks = oil.dtests.checks

raiser = oil.dtests.resolve("Server", 2809, "raiser")
badobj = oil.dtests.resolve("_", 0, "", nil, true, true)

if oil.dtests.flavor.corba then
	badobj = orb:narrow(badobj, "ExceptionRaiser")
end

raisers = {
	[raiser] = function(exception)
		assert(exception._repid == "IDL:ExceptionRaiser/RaisedException:1.0", "wrong exception.")
		assert(exception.reason == "exception", "wrong exception field.")
	end,
	[badobj] = function(exception)
		if oil.dtests.flavor.corba then
			checks.assert(exception, checks.like{
				_repid = "IDL:omg.org/CORBA/TRANSIENT:1.0",
				completed = "COMPLETED_NO",
				profile = {tag=0},
			})
		end
		checks.assert(exception, checks.like{
			host = "_",
			port = 0,
			errmsg = "host not found",
			error = "badconnect",
		})
	end,
}

for raiser, exchecker in pairs(raisers) do
	async = orb:newproxy(raiser, "asynchronous")
	prote = orb:newproxy(raiser, "protected")
	
	--
	-- pcall exception catch
	--
	-- synchronous call
	ok, exception = pcall(raiser.raisenow, raiser)
	assert(not ok, "exception was not raised.")
	exchecker(exception)
	-- asynchronous call
	future = async:raisenow()
	oil.sleep(.1); assert(future:ready())
	ok, exception = future:results()
	assert(not ok, "exception was not raised.")
	exchecker(exception)
	ok, exception = pcall(future.evaluate, future)
	assert(not ok, "exception was not raised.")
	exchecker(exception)

	--
	-- exception handler callback
	--
	function handler(self, exception, operation)
		exchecker(exception)
		if oil.dtests.flavor.corba then
			operation = operation.name
			assert(operation == "raisenow", "wrong operation that raised exception.")
		end
		excount = excount + 1
		return excount
	end
	for case = 1, 3 do
		if case == 1 then
			raiser:__setexcatch(handler)
			async:__setexcatch(handler)
		elseif case == 2 then
			orb:setexcatch(handler, "ExceptionRaiser")
		elseif case == 3 then
			orb:setexcatch(handler)
		end
		
		excount = 0
		-- synchronous call
		result = raiser:raisenow()
		assert(excount == 1, "wrong number of raised exceptions.")
		assert(result == excount, "wrong operation result after exception catch.")
		-- asynchronous call
		future = async:raisenow()
		oil.sleep(.1); assert(future:ready())
		ok, exception = future:results()
		assert(not ok, "exception was not raised.")
		exchecker(exception)
		result = future:evaluate()
		assert(excount == 2, "wrong number of raised exceptions.")
		assert(result == excount, "wrong operation result after exception catch.")
		
		if case == 1 then
			raiser:__setexcatch(nil)
			async:__setexcatch(nil)
		elseif case == 2 then
			orb:setexcatch(nil, "ExceptionRaiser")
		elseif case == 3 then
			orb:setexcatch(nil)
		end
	end
	
	--
	-- protected proxy
	--
	ok, exception = prote:raisenow()
	assert(not ok, "exception was not raised.")
	exchecker(exception)
end

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
