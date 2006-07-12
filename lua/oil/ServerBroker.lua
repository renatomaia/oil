local print   = print
local require = require
local type    = type

local oo      = require "oil.oo"
local assert  = require "oil.assert"

module ("oil.ServerBroker", oo.class)                                       --[[VERBOSE]] local verbose = require "oil.verbose" 

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function register(self, object, intfaceName, key)
	key = key or intfaceName
	-- create servant and return it
	return self.objectmap:register(key, object, intfaceName)
end

function tostring(servant)
  return self.reference:referto(servant:getreference())
end

function run()
	-- TODO[nogara]: see if there is a way to call every one of the ports at 'the same time'
  self.ports:acceptall()
end

function step()

end

function pending()
  return false
end
