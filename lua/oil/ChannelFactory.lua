local require         = require
local print           = print
local pairs           = pairs
local setmetatable    = setmetatable
local oo              = require "oil.oo"

module "oil.ChannelFactory"                                        --[[VERBOSE]] local verbose = require "oil.verbose"

local socket          = require "oil.socket"
local Exception       = require "oil.Exception"
local ObjectCache     = require "loop.collection.ObjectCache"

--------------------------------------------------------------------------------
-- Client connection management ------------------------------------------------

ActiveChannelFactory = oo.class()

function ActiveChannelFactory:create(host, port)
	return socket:connect(host, port)
end

--------------------------------------------------------------------------------

local function connect(self, port)
	return socket:connect(self.host, port)
end

local function channelcache(self, host)
	return ObjectCache{ host = host, retrieve = connect }
end

CachedChannelFactory = oo.class()

function CachedChannelFactory:__init(factory)
	self = oo.rawnew(self, factory)
	self.channels.retrieve = channelcache
end

function CachedChannelFactory:create(host, port)
	return self.channels[host][port]
end

--------------------------------------------------------------------------------

local function bindport(self, port)
	local port, errmsg = socket:bind(self.host, port)
	if not port then self.errmsg = errmsg end
	return port
end

local function portcache(self, host)
	return ObjectCache{ host = host, retrieve = bindport }
end

PassiveChannelFactory = oo.class()

function PassiveChannelFactory:__init(factory)
	self = oo.rawnew(self, factory)
	self.ports = ObjectCache(self.ports)
	self.ports.retrieve = portcache
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

