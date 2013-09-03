local Template = require "oil.dtests.Template"
local T = Template{"Client"} -- master process name

T.Server = [===================================================================[
Caller = {}
function Caller:idle()
	-- empty
end
function Caller:call(obj)
	require("cothread").schedule(coroutine.create(function() obj:ack() end))
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	orb:loadidl[[
		interface Callback { void ack(); };
		interface Caller {
			void call(in Callback obj);
			void idle();
		};
	]]
	Caller.__type = "Caller"
end
orb:newservant(Caller, "object")
orb:run()
----[Server]===================================================================]

T.Client = [===================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()
Caller = oil.dtests.resolve("Server", 2809, "object")

oil.newthread(orb.run, orb)
Caller:call({ ack = function() called = true end })
oil.sleep(.1)
checks:assert(called, checks.is(true))
orb:shutdown()
Caller:idle()
----[Client]===================================================================]

return T:newsuite{ cooperative = true, corba = true }
