local print   = print
local require = require
local type    = type
local print   = print
local pairs   = pairs

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
end

function register(self, object, intfaceName, key)
	-- register object in the dispatcher
	key = key or intfaceName
	-- create servant and return it
	local servant = self.objectmap:register(key, object, intfaceName)
	-- [temporary] put the host/port inside the object, in order to help the 
	-- reference component to encode the profile
	local info = self.ports:getinfo()
	servant._host = info.host
	servant._port = info.port
	print("Host", servant._host)
	return servant
end

function tostring(self, servant)
  return self.reference:referto(servant)
end

function run(self)
	-- TODO[nogara]: see if there is a way to call every one of the ports at 'the same time'
  self.ports:acceptall()
end

function step(self)

end

function pending(self)
  return false
end
