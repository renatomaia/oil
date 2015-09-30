local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
impl = { called = false }
function impl:doit() self.called = true end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	impl.__type = orb:loadidl[[
		interface SomeIface {
			readonly attribute boolean called;
			oneway void doit();
		};
	]]
end
orb:newservant(impl, "object")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
obj = oil.dtests.resolve("Server", 2809, "object")
obj:doit()
assert(obj:_get_called())
oil.sleep(.1)
orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true }
