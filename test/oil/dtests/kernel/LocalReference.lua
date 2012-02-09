local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checker = {}
function checker:isSelf(obj)
	return self == obj
end

orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.corba then
	checker.__type =
		orb:loadidl[[interface Checker { boolean isSelf(in Object obj); };]]
end
orb:newservant(checker, "checker")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks

oil.dtests.init()
checker = oil.dtests.resolve("Server", 2809, "checker")
checks:assert(checker:isSelf(checker), checks.is(true))
--[Client]=====================================================================]

return template:newsuite()