-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Marshaling of CORBA GIOP Protocol Messages
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = _G.assert
local ipairs = _G.ipairs
local pcall = _G.pcall
local type = _G.type

local coroutine = require "coroutine"
local running = coroutine.running

local Mutex = require "cothread.Mutex"

local oo = require "oil.oo"
local class = oo.class

local bit = require "oil.bit"
local endianess = bit.endianess

local giop = require "oil.corba.giop"
local MagicTag = giop.MagicTag
local HeaderSize = giop.HeaderSize
local Header_v1_ = giop.Header_v1_
local MessageHeader_v1_ = giop.MessageHeader_v1_

local Channel = require "oil.protocol.Channel"
local Exception = require "oil.corba.giop.Exception"



local GIOPChannel = class({
	magictag = MagicTag,
	headersize = HeaderSize,
	headertype = Header_v1_[0],
	messagetype = MessageHeader_v1_[0],
	header = {
		magic = MagicTag,
		GIOP_version = {major=1, minor=0},
		byte_order = (endianess() == "little"),
		message_type = nil, -- defined later
		message_size = nil, -- defined later
	},
}, Channel)

function GIOPChannel:sendmsg(msgtype, message, types, values)                   --[[VERBOSE]] verbose:message(true, "send message ",msgtype)
	--
	-- Create GIOP message body
	--
	local encoder = self.codec:encoder()
	encoder:shift(self.headersize) -- alignment accordingly to GIOP header size
	if message then
		encoder:put(message, self.messagetype[msgtype])
	end
	if types then
		local count = values.n or #values
		for index, idltype in ipairs(types) do
			local value
			if index <= count then
				value = values[index]
			end
			local ok, errmsg = pcall(encoder.put, encoder, value, idltype)
			if not ok then
				assert(type(errmsg) == "table", errmsg)
				return nil, errmsg
			end
		end
	end
	local stream = encoder:getdata()
	
	--
	-- Create GIOP message header
	--
	local header = self.header
	header.message_size = #stream
	header.message_type = msgtype
	encoder = self.codec:encoder()
	encoder:struct(header, self.headertype)
	stream = encoder:getdata()..stream
	
	--
	-- Send stream over the channel
	--
	return self:send(stream)
end

function GIOPChannel:receivemsg(timeout)                                        --[[VERBOSE]] verbose:message(true, "receive message from channel")
	local except
	local type, size, decoder = self.pendingmsgtype
	if type then
		size = self.pendingmsgsize
		decoder = self.pendingmsgdecoder
		self.pendingmsgtype = nil
		self.pendingmsgsize = nil
		self.pendingmsgdecoder = nil
	else
		local stream
		stream, except = self:receive(self.headersize, timeout)
		if stream then
			decoder = self.codec:decoder(stream)
			--
			-- Read GIOP message header
			--
			local header = self.headertype
			local magic = decoder:array(header[1].type)
			if magic == self.magictag then
				local version = decoder:struct(header[2].type)
				if version.major == 1 and version.minor == 0 then
					decoder:order(decoder:boolean())
					type = decoder:octet()
					size = decoder:ulong()
				else
					except = Exception{
						error = "badversion",
						message = "illegal GIOP version (got $majorversion.$minorversion)",
						majorversion = version.major,
						minorversion = version.minor,
					}
				end
			else
				except = Exception{
					error = "badstream",
					message = "illegal GIOP magic tag (got $actualtag)",
					actualtag = magic,
				}
			end
		end
	end
	if not except then
		--
		-- Read GIOP message body
		--
		local stream = true
		if size > 0 then
			stream, except = self:receive(size, timeout)
			if stream then
				decoder:append(stream)
			elseif except.error == "timeout" then
				self.pendingheadertype = type
				self.pendingheadersize = header
				self.pendingheaderdecoder = decoder
			end
		end
		if stream then
			local header = self.messagetype[type]
			if header ~= nil then                                                     --[[VERBOSE]] verbose:message(false, "got message ",type)
				if header then
					return type, decoder:struct(header), decoder
				else
					return type
				end
			else
				except = Exception{
					error = "badversion",
					message = "illegal GIOP message type (got $msgtypeid)",
					majorversion = version.major,
					minorversion = version.minor,
					msgtypeid = type,
				}
			end
		end
	end                                                                           --[[VERBOSE]] if except.error == "timeout" then verbose:message(false, "receive operation timed out") elseif except.error ~= "terminated" then verbose:message(false, "error reading message: ",except) else verbose:message(false) end
	return nil, except, self
end



--[[VERBOSE]] local select = _G.select
--[[VERBOSE]] local MessageType = giop.MessageType
--[[VERBOSE]] function verbose.custom:message(...)
--[[VERBOSE]] 	local viewer = self.viewer
--[[VERBOSE]] 	local output = viewer.output
--[[VERBOSE]] 	for i = 1, select("#", ...) do
--[[VERBOSE]] 		local value = select(i, ...)
--[[VERBOSE]] 		if MessageType[value] then
--[[VERBOSE]] 			output:write(MessageType[value])
--[[VERBOSE]] 		elseif type(value) == "string" then
--[[VERBOSE]] 			output:write(value)
--[[VERBOSE]] 		else
--[[VERBOSE]] 			viewer:write(value)
--[[VERBOSE]] 		end
--[[VERBOSE]] 	end
--[[VERBOSE]] end



return GIOPChannel
