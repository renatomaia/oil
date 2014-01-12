local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
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
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
Caller = oil.dtests.resolve("Server", 2809, "object")

Caller:call({ ack = function() called = true end })
oil.sleep(.1)
assert(called)
orb:shutdown()
Caller:idle()
--[Client]=====================================================================]

return template:newsuite{ cooperative = true, corba = true }
