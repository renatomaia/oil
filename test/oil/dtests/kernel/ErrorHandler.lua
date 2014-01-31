local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
exception = { _repid = "IDL:ExceptionRaiser/RaisedException:1.0",
	reason = "exception",
}

Raiser = {}
function Raiser:raisenow()
	error(exception)
end
function Raiser:success()
	return success
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	orb:loadidl[[
		interface ExceptionRaiser {
			exception RaisedException {
				string reason;
			};
			void raisenow() raises (RaisedException);
			boolean success();
		};
	]]
	Raiser.__type = "ExceptionRaiser"
end

orb:setexhandler(function(error)
	success = (error == exception)
	return {
		_repid = "IDL:omg.org/CORBA/INTERNAL:1.0",
		completed = "COMPLETED_YES",
		minor = 1234,
	}
end)

orb:newservant(Raiser, "Raiser")

orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks
orb = oil.dtests.init()

Raiser = oil.dtests.resolve("Server", 2809, "Raiser")

ok, ex = pcall(Raiser.raisenow, Raiser)
checks.assert(ok, checks.equal(false))
checks.assert(ex, checks.like({
	_repid = "IDL:omg.org/CORBA/INTERNAL:1.0",
	completed = "COMPLETED_YES",
	minor = 1234,
}))
checks.assert(Raiser:success(), checks.equal(true))

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
