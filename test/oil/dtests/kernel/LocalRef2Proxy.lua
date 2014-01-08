local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checker = {}
function checker:isSelf(obj)
	return proxy:_is_equivalent(obj)
end

orb = oil.dtests.init{ port = 2809, localrefs = "proxy" }
if oil.dtests.flavor.corba then
	checker.__type =
		orb:loadidl[[interface Checker { boolean isSelf(in Object obj); };]]
end
proxy = orb:newproxy(tostring(orb:newservant(checker, "checker")), nil, checker.__type)
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

orb = oil.dtests.init()
checker = oil.dtests.resolve("Server", 2809, "checker")
checks:assert(checker:isSelf(checker), checks.is(true))
orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true }
