local Suite = require "loop.test.Suite"
local Template = require"oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
oil.init{ port = 2809 }
oil.newservant({ __type = "::CORBA::InterfaceDef", __objkey = "object" })
oil.run()
--[Server]=====================================================================]

Client = [=====================================================================[
checks = oil.dtests.checks
object = oil.dtests.resolve("Server", 2809, "object")

checks:assert(object:_is_a("IDL:omg.org/CORBA/InterfaceDef:1.0"), checks.is(true))
--[Client]=====================================================================]

return template:newsuite{ corba = true }
