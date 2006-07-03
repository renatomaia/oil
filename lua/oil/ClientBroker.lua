
local oo      = require "oil.oo"

module ("oil.ClientBroker", oo.class)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function class(self, interface, manager, orb)                                   --[[VERBOSE]] verbose:proxy("new proxy class for ", interface.repID)
	object = self.reference:decode(object)
	
	object = myReferenceResolver:decode(object)
	if not interface then
		interface = object._type_id  
	end
	
	local class = Manager:getclass(interface)
	if not class then
		if Manager.lookup then
			interface = Manager:lookup(interface) 
			if interface then
				class = Manager:getclass(interface.repID)
			end
		end
		if not class then
			object = Manager:getclass("IDL:omg.org/CORBA/Object:1.0")(object) 
			object = object:_narrow()
		end
	end
	if class then object = class(object) end            

	rawset(object, "_orb", init())
	return object
end

function getObjectInterface(self)
	return Object._iface
end


