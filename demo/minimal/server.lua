local idl = require "oil.corba.idl"

local iface = idl.interface{
	definitions = {
		quiet = idl.attribute{ idl.boolean },
		count = idl.attribute{ idl.long, readonly=true },
		say_hello_to = idl.operation{
			parameters = {{ type = idl.string, name = "name" }},
			result = idl.string,
		},
	},
}

--------------------------------------------------------------------------------

local hello_impl = { count = 0, quiet = true }
function hello_impl:say_hello_to(name)
	self.count = self.count + 1
	local msg = "Hello " .. name .. "! ("..self.count.." times)"
	if not self.quiet then print(msg) end
	return msg
end

--------------------------------------------------------------------------------

oil.BasicSystem = false
local oil = require "oil"

oil.main(function()
	local function dummy(self, ...) return ... end
	local orb = oil.init{
		flavor = "corba.server",
		tcpoptions = {reuseaddr=true},
		port = 2809,
		TypeRepository = {
			types = { resolve = dummy, register = dummy },
			indexer  = require("oil.corba.giop.Indexer")(),
		}
	}
	orb:newservant(hello_impl, "MyHello", iface)
	orb:run()
end)
