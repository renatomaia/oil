local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809 }
orb:newservant({ __type = "::CORBA::InterfaceDef", __objkey = "object1" })
orb:newservant({}, "object2", "::CORBA::InterfaceDef")
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
oil.dtests.init()
checks = oil.dtests.checks
object1 = oil.dtests.resolve("Server", 2809, "object1")
object2 = oil.dtests.resolve("Server", 2809, "object2")

checks:assert(object1:_is_a("IDL:omg.org/CORBA/InterfaceDef:1.0"), checks.is(true))
checks:assert(object2:_is_a("IDL:omg.org/CORBA/InterfaceDef:1.0"), checks.is(true))
--[Client]=====================================================================]

return template:newsuite{ corba = true }
