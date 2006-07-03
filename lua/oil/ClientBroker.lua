
local oo      = require "oil.oo"

module ("oil.ClientBroker", oo.class)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newproxy(self, ref, intfaceName)                                   --[[VERBOSE]] verbose:proxy("new proxy class for ", interface.repID)
	local decodedReference = self.reference:resolve(ref)
	local proxy = self.factory:create(decodedReference, self.protocol, intfaceName)
	return proxy 
end

function getObjectInterface(self)
	return Object._iface
end


