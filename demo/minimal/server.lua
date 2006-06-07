require "oil.iiop"     -- transport protocol used (CORBA default is IIOP)
require "oil.manager"  -- object manager for resolving object references
require "oil.orb"      -- ORB server support

oil.verbose.level(4)

--------------------------------------------------------------------------------
local ifaces = oil.idl.module{ name = "Hello" }
ifaces.definitions.Person = oil.idl.interface{ members = {
	getfullname = oil.idl.operation{ result = oil.idl.string },
}}
ifaces.definitions.Hello = oil.idl.interface{
	members = {
		quiet = oil.idl.attribute{ oil.idl.boolean },
		count = oil.idl.attribute{ oil.idl.long, readonly=true },
		say_hello_to = oil.idl.operation{
			parameters = {{ type = ifaces.definitions.Person, name = "person" }},
			result = oil.idl.string,
		},
		new_person = oil.idl.operation{
			parameters = {
				{ type = oil.idl.string , name = "name" },
				{ type = oil.idl.boolean, name = "male" },
			},
			result = ifaces.definitions.Person,
		},
	},
}
--------------------------------------------------------------------------------
local hello_impl = { count = 0, quiet = true }
function hello_impl:say_hello_to(person)
	self.count = self.count + 1
	local msg = string.format("Hello %s, you're customer number %d",
	                          person:getfullname(), self.count)
	if not self.quiet then print(msg) end
	return msg
end
function hello_impl:new_person(name, male)
	return {
		getfullname = function()
			return string.format("%s %s", male and "Mr." or "Mrs.", name)
		end
	}
end
--------------------------------------------------------------------------------
local orb = oil.orb.init{ manager = oil.manager.new() }
local hello = orb:object(hello_impl, ifaces.definitions.Hello)

local file = io.open("hello.ior", "w")
if file then
	file:write(hello:_ior())
	file:close()
else
	print(hello:_ior())
end

orb:run()
