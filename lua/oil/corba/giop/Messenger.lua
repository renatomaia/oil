-- Project: OiL - ORB in Lua
-- Release: 0.5
-- Title  : Marshaling of CORBA GIOP Protocol Messages
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local assert = _G.assert
local ipairs = _G.ipairs
local pcall = _G.pcall
local type = _G.type

local oo = require "oil.oo"
local class = oo.class

local bit = require "oil.bit"
local endianess = bit.endianess

local giop = require "oil.corba.giop"
local MagicTag = giop.MagicTag
local HeaderSize = giop.HeaderSize
local Header_v1_ = giop.Header_v1_
local MessageHeader_v1_ = giop.MessageHeader_v1_

local Exception = require "oil.corba.giop.Exception"                            --[[VERBOSE]] local verbose = require "oil.verbose"

module(..., class)

magictag    = MagicTag
headersize  = HeaderSize
headertype  = Header_v1_[0]
messagetype = MessageHeader_v1_[0]

header = {
	magic        = MagicTag,
	GIOP_version = {major=1, minor=0},
	byte_order   = (endianess() == "little"),
	message_type = nil, -- defined later
	message_size = nil, -- defined later
}

function sendmsg(self, channel, msgtype, message, types, values)                --[[VERBOSE]] verbose:message(true, "send message ",msgtype," ",message)
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
	channel:trylock("write")
	local success, except = channel:send(stream)
	channel:freelock("write")
	if not success then
		except = Exception{
			error = "badchannel",
			errmsg = except,
			message = "unable to write into $channel ($errmsg)",
			channel = channel,
		}
	end                                                                           --[[VERBOSE]] verbose:message(false)
	return success, except
end

function receivemsg(self, channel, timeout)                                     --[[VERBOSE]] verbose:message(true, "receive message from channel")
	local result, except
	local type, size, decoder = channel.pendingmsgtype
	if type then
		size = channel.pendingmsgsize
		decoder = channel.pendingmsgdecoder
		channel.pendingmsgtype = nil
		channel.pendingmsgsize = nil
		channel.pendingmsgdecoder = nil
	else
		result, except = channel:probe(self.headersize, timeout)
		if result then
			decoder = self.codec:decoder(result)
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
						message = "illegal GIOP version (got $major.$minor)",
						major = version.major,
						minor = version.minor,
					}
				end
			else
				except = Exception{
					error = "badstream",
					minor = 8,
					message = "illegal GIOP magic tag (got $actualtag)",
					actualtag = magic,
				}
			end
		elseif except == "timeout" then
			except = Exception{
				error = "timeout",
				message = "timeout",
			}
		else
			if except == "closed" then channel:close() end
			except = Exception{
				error = "badchannel",
				message = "unable to read from channel ($error)",
				errmsg = except,
				channel = channel,
			}
		end
	end
	if not except then
		--
		-- Read GIOP message body
		--
		if size > 0 then
			result, except = channel:probe(size, timeout)
		else
			result, except = "", nil
		end
		if result then
			decoder:append(result)
			local header = self.messagetype[type]
			if header then                                                            --[[VERBOSE]] verbose:message(false, "got message ",type, header)
				return type, decoder:struct(header), decoder
			elseif header == nil then
				except = Exception{
					error = "badversion",
					errmsg = "illegal GIOP message type",
					message = "$errmsg (got $msgtypeid)",
					major = version.major,
					minor = version.minor,
					msgtypeid = type,
				}
			end
		elseif except == "timeout" then
			except = Exception{
				error = "timeout",
				message = "timeout",
			}
			channel.pendingheadertype = type
			channel.pendingheadersize = header
			channel.pendingheaderdecoder = decoder
		else
			if except == "closed" then channel:close() end
			except = Exception{
				error = "badchannel",
				message = "unable to read from $channel ($errmsg)",
				errmsg = except,
				channel = channel,
			}
		end
	end                                                                           --[[VERBOSE]] verbose:message(false, "error reading message: ",except)
	return nil, except, channel
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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
