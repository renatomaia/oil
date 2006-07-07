local print   = print
local require = require
local oo      = require "oil.oo"

module ("oil.ClientBroker", oo.class)                                       --[[VERBOSE]] local verbose = require "oil.verbose" 


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newproxy(self, ref, intfaceName)                                   --[[VERBOSE]] verbose:proxy("new proxy class for ", intfaceName)
	local decodedReference = self.reference:resolve(ref)
	print( self.protocol, "protocol")
	local proxy = self.factory:create(decodedReference, self.protocol, intfaceName)
	return proxy 
end

