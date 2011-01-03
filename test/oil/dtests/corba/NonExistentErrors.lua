local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809 }
oil.sleep(2)
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
checks = oil.dtests.checks
object = oil.dtests.resolve("Server", 2809, "object", nil, true, true)

-- synchronous call
result = object:_non_existent()
checks:assert(result, checks.is(true))
--[Client]=====================================================================]

return template:newsuite{ corba = true }
