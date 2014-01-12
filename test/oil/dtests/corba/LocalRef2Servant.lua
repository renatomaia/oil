local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
checker = {}
function checker:isSelf(obj)
	return obj == servant
end

orb = oil.dtests.init{ port = 2809, localrefs = "servant" }
if oil.dtests.flavor.corba then
	checker.__type =
		orb:loadidl[[interface Checker { boolean isSelf(in Object obj); };]]
end
servant = orb:newservant(checker, "checker")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
checker = oil.dtests.resolve("Server", 2809, "checker")
assert(checker:isSelf(checker))
orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true }
