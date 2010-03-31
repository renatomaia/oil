local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
Caller = {}
function Caller:call(obj)
	obj:ack()
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	orb:loadidl[[
		interface Callback { void ack(); };
		interface Caller { void call(in Callback obj); };
	]]
	Caller.__type = "Caller"
end
orb:newservant(Caller, "object")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
Caller = oil.dtests.resolve("Server", 2809, "object")
for i = 1, 2 do
	oil.newthread(orb.run, orb)
	Caller:call({ ack = function() end })
	orb:shutdown()
	oil.sleep(1)
end

--[Client]=====================================================================]

return template:newsuite{ cooperative = true }
