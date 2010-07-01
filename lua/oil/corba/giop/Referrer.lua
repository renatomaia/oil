-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Interoperable Object Reference (IOR) support
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber

local string = require "string"
local format = string.format
local char = string.char

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"
local objrepID = idl.object.repID

local giop = require "oil.corba.giop"
local ioridl = giop.IOR
local _interface = giop.ObjectOperations._interface

local Exception = require "oil.corba.giop.Exception"

module(...); local _ENV = _M


local function byte2hexa(value)
	return (value:gsub('(.)', function (char)
		-- TODO:[maia] check char to byte conversion
		return (format("%02x", char:byte()))
	end))
end

local function hexa2byte(value)
	return (value:gsub('(%x%x)', function (hexa)
		-- TODO:[maia] check byte to char conversion
		return (char(tonumber(hexa, 16)))
	end))
end


class(_ENV)


function _ENV:IOR(stream)
	local decoder = self.codec:decoder(hexa2byte(stream), true)
	return decoder:struct(ioridl)
end

function _ENV:corbaloc(encoded)
	for token, data in encoded:gmatch("(%w*):([^,]*)") do
		if token == "" or token == "iiop" then
			local profile, except = self.profiler:decodeurl(data)
			if profile then
				return setmetatable({
					type_id = objrepID,
					profiles = { profile },
				}, ioridl)
			else
				return nil, except
			end
		end
	end
	return nil, Exception{
		error = "badcorbaloc",
		message = "no supported protocol found in corbaloc (got $reference)",
		reference = encoded,
	}
end


function _ENV:newreference(key, type)
	local result, except = self.listener:getaddress()
	if result then
		local profiles = {}
		result, except = self.profiler:encode(profiles, key, result)
		if result then
			result, except = setmetatable({
				type_id = type.repID,
				profiles = profiles,
			}, ioridl)
		end
	end
	return result, except
end

function _ENV:islocal(reference)
	local listener = self.listener
	if listener then
		local address = listener:getaddress("probe") -- only if avaliable
		if address then
			local profiler = self.profiler
			local profiles = reference.profiles
			for i = 1, #profiles do
				local profile = profiles[i]
				if profile.tag == 0 then
					local result = profiler:belongsto(profile.profile_data, address)
					if result then return result end
				end
			end
		end
	end
end

function _ENV:typeof(reference, timeout)
	local requester = self.requester
	if requester then                                                             --[[VERBOSE]] verbose:proxies(true, "attempt to discover interface a remote object")
		local request = requester:newrequest(reference, _interface)
		if request then
			local ok, type = request:results(timeout)
			if ok then                                                                --[[VERBOSE]] verbose:proxies(false, "interface discovered")
				return type
			end
		end
	end                                                                           --[[VERBOSE]] verbose:proxies(false, "discovery failed, using interface defined in the IOR")
	return reference.type_id
end

function _ENV:encode(reference)
	local encoder = self.codec:encoder(true)
	encoder:struct(reference, ioridl)
	return "IOR:"..byte2hexa(encoder:getdata())
end

function _ENV:decode(encoded)
	local token, stream = encoded:match("^(%w+):(.+)$")
	local decoder = self[token]
	if decoder then
		return decoder(self, stream)
	end
	return nil, Exception{
		error = "badobjref",
		message = "invalid stringfied reference (got $reference)",
		reference = enconded,
		format = token,
	}
end
