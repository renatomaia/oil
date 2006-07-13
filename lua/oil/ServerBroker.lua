local print   = print
local require = require
local type    = type

local oo      = require "oil.oo"
local assert  = require "oil.assert"

module ("oil.ServerBroker", oo.class)                                       --[[VERBOSE]] local verbose = require "oil.verbose" 

local MainORB
local map = {}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function init(self, config)
	-- create acceptor using configuration received from the user
  self.ports:init(config)
	-- bind acceptor in dispatcher
  
end

function register(self, object, intfaceName, key)
	-- register object in the dispatcher
	key = key or intfaceName
	-- create servant and return it
	local servant = self.objectmap:register(key, object, intfaceName)
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
