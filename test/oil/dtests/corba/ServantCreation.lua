local Suite = require "loop.test.Suite"
local Template = require "oil.dtests.Template"
local template = Template{"Client"} -- master process name

Server = [=====================================================================[
orb = oil.dtests.init{ port = 2809 }
if oil.dtests.flavor.ludo then
	function isa(self, iface)
		return iface == "IDL:omg.org/CORBA/InterfaceDef:1.0"
	end
end
orb:newservant{
	_is_a = isa,
	__objkey = "object1",
	__type = "::CORBA::InterfaceDef",
}
orb:newservant(
	{ _is_a = isa },
	"object2",
	"::CORBA::InterfaceDef"
)
orb:run()
--[Server]=====================================================================]

Client = [=====================================================================[
orb = oil.dtests.init()
object1 = oil.dtests.resolve("Server", 2809, "object1")
object2 = oil.dtests.resolve("Server", 2809, "object2")

assert(object1:_is_a("IDL:omg.org/CORBA/InterfaceDef:1.0") == true)
assert(object2:_is_a("IDL:omg.org/CORBA/InterfaceDef:1.0") == true)

orb:shutdown()
--[Client]=====================================================================]

return template:newsuite()
