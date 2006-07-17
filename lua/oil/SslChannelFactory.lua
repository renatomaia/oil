local require         = require
local print           = print
local pairs           = pairs
local setmetatable    = setmetatable
local oo              = require "oil.oo"

module "oil.SslChannelFactory"                                        --[[VERBOSE]] local verbose = require "oil.verbose"

local socket          = require "oil.sslsocket"
local Exception       = require "oil.Exception"
local ObjectCache     = require "loop.collection.ObjectCache"

--------------------------------------------------------------------------------
-- Client connection management ------------------------------------------------

ActiveChannelFactory = oo.class()

function ActiveChannelFactory:__init(params)
	self.params = params
	return oo.rawnew(self)
end

function ActiveChannelFactory:create(host, port)
	return socket:ssl_connect(host, port, self.params)
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
	return self
end

function CachedChannelFactory:create(host, port)
	return self.channels[host][port]
end

--------------------------------------------------------------------------------

local function bindport(self, port)
	print("params", self.params)
	local port, errmsg = socket:ssl_bind(self.host, port, self.params)
	if not port then self.errmsg = errmsg end
	socket:listen(5)
	return port
end

local function portcache(self, host)
	return ObjectCache{ host = host, retrieve = bindport }
end

PassiveChannelFactory = oo.class()

function PassiveChannelFactory:__init(factory, params)
	print("passivechannelfactory", factory, params)
	self = oo.rawnew(self, factory)
	self.params = params
	self.ports = ObjectCache(self.ports)
	self.ports.retrieve = portcache
	return self
end

function PassiveChannelFactory:create(host, port)
	local port = self.ports[host][port]
	if not port then print(self.errmsg) return nil, self.errmsg end
	local channel, errmsg = port:accept()
	if not channel then
		port:close()
		self.ports[host][port] = nil
	end
	return channel, errmsg
end

