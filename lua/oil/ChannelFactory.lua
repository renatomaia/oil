local require         = require
local print           = print
local pairs           = pairs
local setmetatable    = setmetatable
local oo              = require "oil.oo"

module "oil.ChannelFactory"                                        --[[VERBOSE]] local verbose = require "oil.verbose"

local Exception       = require "oil.Exception"
local ObjectCache     = require "loop.collection.ObjectCache"

--------------------------------------------------------------------------------
-- Client connection management ------------------------------------------------

ActiveChannelFactory = oo.class()

function ActiveChannelFactory:create(host, port)
	return self.luasocket:connect(host, port)
end

--------------------------------------------------------------------------------

local function connect(self, port)
	return self.luasocket:connect(self.host, port)
end

local function channelcache(self, host)
	return ObjectCache{ host = host, retrieve = connect }
end

CachedChannelFactory = oo.class()

function CachedChannelFactory:__init(factory)
	self = oo.rawnew(self, factory)
	self.channels.retrieve = channelcache
	return self
end

function CachedChannelFactory:create(host, port)
	return self.channels[host][port]
end

--------------------------------------------------------------------------------

local function bindport(self, port)
	local port, errmsg = self.luasocket:bind(self.host, port)
	if not port then self.errmsg = errmsg end
	return port
end

local function portcache(self, host)
	return ObjectCache{ host = host, retrieve = bindport }
end

PassiveChannelFactory = oo.class()

function PassiveChannelFactory:__init(factory)
	local factory = oo.rawnew(self, factory)
	factory.ports = ObjectCache(self.ports)
	function factory.ports:retrieve(host)
		local cache = ObjectCache()
		function cache:retrieve(port)
			local port, errmsg = factory.luasocket:bind(host, port)
			if not port then factory.errmsg = errmsg end
			return port
		end
		return cache
	end
	return factory
end

function PassiveChannelFactory:create(host, port)
	local port = self.ports[host][port]
	if not port then return nil, self.errmsg end
	local channel, errmsg = port:accept()
	if not channel then
		port:close()
		self.ports[host][port] = nil
	end
	return channel, errmsg
end

function PassiveChannelFactory:bind(host, port)
	return self.ports[host][port] ~= nil
end

function PassiveChannelFactory:free(host, port)
	local port = self.ports[host][port]
	if port then port:close() end
	return port ~= nil
end
