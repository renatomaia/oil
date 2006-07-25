local require         = require
local print           = print
local pairs           = pairs
local type            = type
local setmetatable    = setmetatable
local oo              = require "oil.oo"

module "oil.ChannelFactorySelect"                                        --[[VERBOSE]] local verbose = require "oil.verbose"

local Exception       = require "oil.Exception"
local ObjectCache     = require "loop.collection.ObjectCache"
local OrderedSet      = require "loop.collection.OrderedSet"
local MapWithKeyArray = require "loop.collection.MapWithArrayOfKeys" 

--------------------------------------------------------------------------------
-- Client connection management ------------------------------------------------

ActiveChannelFactory = oo.class()

function ActiveChannelFactory:create(host, port)
	return self.luasocket:connect(host, port, client_params)
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
	local port, errmsg = self.luasocket:bind(self.host, port, server_params)
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
	factory.connections = MapWithKeyArray()
	factory.ready = OrderedSet() -- queue of ready connections
	function factory.ports:retrieve(host)
		local cache = ObjectCache()
		function cache:retrieve(port)
			local port, errmsg = factory.luasocket:bind(host, port)
			if not port then factory.errmsg = errmsg end
			factory.connections:add(port)
			return port
		end
		return cache
	end
	return factory
end

function PassiveChannelFactory:create(host, port)
	local port = self.ports[host][port]
	if not port then return nil, self.errmsg end
	local ready = self.ready
	local connections = self.connections
	if self.ready:empty() then
		local attempts = 0 -- how much attempts to select a socket?
		local giveup = false
		repeat
			attempts = attempts + connections:size()
			local selected = self.luasocket:select(connections, Empty, timeout)
			if selected[port] then
				selected[port] = nil
				local channel, errmsg = port:accept()
				if not channel then
					port:close()
					self.ports[host][port] = nil
				end
				channel = Channel(channel, self)
				connections:add(channel.socket, channel)
			end
			for sock in pairs(selected) do
				if type(sock) ~= "number" then
					local channel = connections[sock]
					ready:enqueue(channel)
				end
			end
			if timeout and timeout >= 0 then
				-- select has already tried to select ready sockets for timeout seconds
				if attempts > 1 or connections:size() == 1 then
					-- there were other attempts to select sockets besides
					-- the first one to select the port socket or ...
					-- no new connections were created
					giveup = true
				end
			else
				giveup = not ready:empty()
			end
		until giveup
		
		return ready:dequeue()
	else
		return ready:dequeue()
	end
end

function PassiveChannelFactory:bind(host, port, params)
	return self.ports[host][port] ~= nil
end

function PassiveChannelFactory:free(host, port)
	local port = self.ports[host][port]
	if port then port:close() end
	return port ~= nil
end

-------------------------------------------------------------------------------
-- Wrapper for socket
-------------------------------------------------------------------------------
Channel = oo.class{}

function Channel:__init(socket, factory)
	return oo.rawnew(self, {
  	socket = socket,
		factory = factory,
	})
end

function Channel:send(...)
	return self.socket:send(...)
end

function Channel:receive(...)
	return self.socket:receive(...)
end

function Channel:close(...)
	self.factory.connections:remove(self.socket)
	return self.socket:close(...)
end

