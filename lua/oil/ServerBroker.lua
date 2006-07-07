local print   = print
local require = require
local oo      = require "oil.oo"

module ("oil.ServerBroker", oo.class)                                       --[[VERBOSE]] local verbose = require "oil.verbose" 

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newobject(self, object, intfaceName, key)
	if type(interface) == "string" then
		if Manager.lookup then
			interface = Manager:lookup(interface) or interface
		end
	end
	if Manager then
		if type(interface) == "string" then
			local iface = Manager:getiface(interface)
			if iface then 
				interface = iface
			else 
				assert.illegal(interface, "interface, unable to get definition")
			end
		else
			interface = Manager:putiface(interface)
		end
	else
		assert.type(interface, "idlinterface", "object interface")
	end
	return init():object(object, interface, key)
end


