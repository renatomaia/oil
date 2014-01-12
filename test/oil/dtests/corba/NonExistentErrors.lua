local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809 }
orb:newservant{ __type = "::CORBA::InterfaceDef", __objkey = "object" }
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
object = oil.dtests.resolve("Server", 2809, "object", nil, false, true)
inexistent = oil.dtests.resolve("Server", 2809, "inexistent", nil, true, true)

-- synchronous call
assert(inexistent:_non_existent())

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite{ corba = true }
