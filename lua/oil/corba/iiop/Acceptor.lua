--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua                                                  --
-- Release: 0.4                                                               --
-- Title  : Client-side CORBA GIOP Protocol specific to IIOP                  --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See section 15.7 of CORBA 3.0 specification.                             --
--   See section 13.6.10.3 of CORBA 3.0 specification for IIOP corbaloc.      --
--------------------------------------------------------------------------------
-- channels:Facet
-- 	channel:object retieve(configs:table, [probe:boolean])
-- 	channel:object dispose(configs:table)
-- 	configs:table default([configs:table])
-- 
-- sockets:Receptacle
-- 	socket:object tcp()
-- 	input:table, output:table select([input:table], [output:table], [timeout:number])
--------------------------------------------------------------------------------

local ipairs       = ipairs
local next         = next
local rawget       = rawget
local setmetatable = setmetatable
local type         = type

local math = require "math"

local ObjectCache       = require "loop.collection.ObjectCache"
local UnorderedArraySet = require "loop.collection.UnorderedArraySet"
local OrderedSet        = require "loop.collection.OrderedSet"
local Wrapper           = require "loop.object.Wrapper"

local oo        = require "oil.oo"
local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.iiop.Acceptor", oo.class)

context = false

--------------------------------------------------------------------------------
-- connection management

local function dummy() end

local function release_wrapped_socket(self)
	UnorderedArraySet.add(self.port, self)
end

local function release_plain_socket(self)
	UnorderedArraySet.add(self.port, self.__object)
end

local function probe_wrapped_socket(self)
	local list = { self }
	return self.context.sockets:select(list, nil, 0)[1] == list[1]
end

local list = {}
local function probe_plain_socket(self)
	list[1] = self.__object
	return self.context.sockets:select(list, nil, 0)[1] == list[1]
end

local function release_socket(self)
	self.__object:close()
	self.__object = nil
	self.context  = nil
	self.probe    = nil
	self.release  = dummy
	self.close    = nil
	return setmetatable(self, nil)
end

--------------------------------------------------------------------------------

Port = oo.class()

function Port:__init(object)
	self = oo.rawnew(self, object)
	
	self.wrapped = ObjectCache()
	function self.wrapped.retrieve(_, socket)
		if type(socket) ~= "table" then
			socket = Wrapper{
				__object = socket,
				probe   = probe_plain_socket,
				release = release_plain_socket,
			}
		else
			socket.probe   = probe_wrapped_socket
			socket.release = release_wrapped_socket
		end
		socket.context = self.context
		socket.port   = self
		socket.close  = release_socket
		return socket
	end
	
	UnorderedArraySet.add(self, self.__object)
	
	return self
end

function Port:accept(probe)                                                     --[[VERBOSE]] verbose:channels("accepting channel from port with ",#self," active channels")
	local except
	if OrderedSet.empty(self) then
		local selected = self.context.sockets:select(self, nil, probe and 0)
		for _, channel in ipairs(selected) do
			if channel == self.__object then
				channel, except = channel:accept()
			else
				UnorderedArraySet.remove(self, channel)
			end
			OrderedSet.enqueue(self, channel)
		end
	end
	if probe then
		return not OrderedSet.empty(self)
	elseif not except then
		return self.wrapped[ OrderedSet.dequeue(self) ]
	else
		return nil, except
	end
end

--------------------------------------------------------------------------------
-- channel cache for reuse

function __init(self, object)
	self = oo.rawnew(self, object)
	--
	-- cache of active channels
	-- self.cache[host][port] == <channel accepted at host:port>
	--
	self.cache = ObjectCache()
	function self.cache.retrieve(_, host)
		local cache = ObjectCache()
		function cache.retrieve(_, port)
			local socket, errmsg
			socket, errmsg = self.context.sockets:tcp()
			if socket then
				_, errmsg = socket:bind(host, port)
				if _ then
					_, errmsg = socket:listen()
					if _ then                                                             --[[VERBOSE]] verbose:channels("new port binded to ",host,":",port)
						return Port{
							context = self.context,
							__object = socket,
						}
					else
						self.except = Exception{ "NO_RESOURCES", minor_code_value = 0,
							message = "unable to listen to port of host",
							reason = "listen",
							error = errmsg,
							host = host, 
							port = port,
						}
					end
				else
					self.except = Exception{ "NO_RESOURCES", minor_code_value = 0,
						message = "unable to bind to port of host",
						reason = "bind",
						error = errmsg,
						host = host, 
						port = port,
					}
				end
			else
				self.except = Exception{ "NO_RESOURCES", minor_code_value = 0,
					message = "unable to create new socket due to error",
					reason = "socket",
					error = except,
				}
			end
		end
		return cache
	end
	
	return self
end

--------------------------------------------------------------------------------
-- channel factory

function retrieve(self, profile, probe)                                         --[[VERBOSE]] verbose:channels("retrieve channel accepted from ",profile.host,":",profile.port)
	local port = self.cache[profile.host][profile.port]
	if port then
		return port:accept(probe)
	else
		return nil, self.except
	end
end

function dispose(self, profile)                                                 --[[VERBOSE]] verbose:channels("disposing channels accepted from ",profile.host,":",profile.port)
	local ports = rawget(self.cache, profile.host)
	local port = ports and rawget(ports, profile.port)
	if port then
		ports[profile.port] = nil
		if next(ports) == nil then
			self.cache[profile.host] = nil
		end
		local result, except = port.__object:close()
		if result then
			UnorderedArraySet.remove(port, port.__object)
			while not OrderedSet.empty(port) do
				UnorderedArraySet.add(port, OrderedSet.dequeue(port))
			end
			result = port
		end
		return result, except
	else
		return nil, "already disposed"
	end
end

local PortLowerBound = 2809 -- inclusive (never at first attempt)
local PortUpperBound = 9999 -- inclusive

function default(self, profile)
	profile = profile or {}
	profile.host = profile.host or "*"
	if not profile.port then
		local start = PortLowerBound + math.random(PortUpperBound - PortLowerBound)
		local count = start
		local port
		repeat
			port = self.cache[profile.host][count]
			if port then
				profile.port = count
			else
				local except = self.except
				if except.reason == "listen" or except.reason == "bind" then
					if count >= PortUpperBound
						then count = PortLowerBound
						else count = count + 1
					end
				else
					return nil, except
				end
			end
		until port or count == start
	end
	return profile
end
