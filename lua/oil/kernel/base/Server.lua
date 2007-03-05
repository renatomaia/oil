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
	if config.ports then
		for k, v in pairs(config.ports) do
    	self.ports[k]:init(v)
		end
	else
		for key, port in self.ports:__all() do
			port:init(config)
		end
	end
end

function register(self, object, intfaceName, key)
	-- register object in the dispatcher
	key = key or intfaceName
	-- create servant and return it
	return self.objectmap:register(key, object, intfaceName)
end

function tostring(self, servant, portName)
	if not portName then
		-- get all the references and return them inside a table
		local references = {}
		for key, port in self.ports:__all() do
			local info = port:getinfo()
			references[key] = self.reference[key]:referto(servant, info)
		end
		return references
	else
		-- return only the reference requested
		local info = self.ports[portName]:getinfo()
		print(portName, info)
		info.objectid = servant._objectid
  	return self.reference[portName]:referto(servant, info)
	end
end

function run(self)
	for key, port in self.ports:__all() do
		print( key, "accepting connections" )
		port:acceptall()
	end
end

function step(self)

end

function pending(self)
  return false
end
