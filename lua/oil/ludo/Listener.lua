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
-- Title  : Server-side LuDO Protocol                                         --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- listener:Facet
-- 	configs:table default([configs:table])
-- 	channel:object, [except:table] getchannel(configs:table)
-- 	request:object, [except:table], [requests:table] = getrequest(channel:object, [probe:boolean])
-- 
-- channels:Receptacle
-- 	channel:object retieve(configs:table)
-- 	configs:table default([configs:table])
-- 
-- codec:Receptacle
-- 	encoder:object encoder()
-- 	decoder:object decoder(stream:string)
--------------------------------------------------------------------------------

local select = select
local tonumber = tonumber
local unpack = unpack

local oo        = require "oil.oo"
local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.ludo.Listener", oo.class)

oo.class(_M, Messenger)

context = false

--------------------------------------------------------------------------------

function getchannel(self, configs, probe)
	return self.context.channels:retrieve(configs, probe)
end

--------------------------------------------------------------------------------

function freeaccess(self, configs)                                         --[[VERBOSE]] verbose:listen("closing all channels with configs ",configs)
	local channels = self.context.channels
	return channels:dispose(configs)
end

--------------------------------------------------------------------------------

function freeachannel(self, channel)                                          --[[VERBOSE]] verbose:listen "close channel"
	return channel:close()
end

--------------------------------------------------------------------------------

local Request = oo.class()

function Request:__init(requestid, objectkey, operation, ...)                   --[[VERBOSE]] verbose:listen("got request for request ",requestid," to object ",objectkey,":",operation)
	self = oo.rawnew(self, {...})
	self.requestid = requestid
	self.object_key = objectkey
	self.operation = operation
	self.paramcount = select("#", ...)
	return self
end

function Request:params()
	return unpack(self, 1, self.paramcount)
end

function getrequest(self, channel, probe)
	local result, except = true
	if channel:trylock("read", not probe) then
		if not probe or channel:probe() then
			result, except = channel:receive()
			if result then
				result = tonumber(result)
				if result then
					result, except = channel:receive(result)
					if result then
						local decoder = self.context.codec:decoder(result)
						result = Request(decoder:get())
						result.channel = channel
						channel[result.requestid] = result
					end
				else
					except = "LuDO protocol: invalid message size"
				end
			else
				if except == "closed" then                                              --[[VERBOSE]] verbose:listen("client closed the connection")
					channel:close()
					result, except = true, nil
				else
					except = "LuDO protocol: socket error "..except
				end
			end
		end
		channel:freelock("read")
	end
	return result, except
end

--------------------------------------------------------------------------------

local MessageFmt = "%d\n%s"

function sendreply(self, request, ...)                                          --[[VERBOSE]] verbose:listen("got reply for request ",request.requestid," to object ",request.object_key,":",request.operation)
	local channel = request.channel
	local encoder = self.context.codec:encoder()
	encoder:put(request.requestid, ...)
	channel[request.requestid] = nil
	local data = encoder:__tostring()
	local result, except = channel:send(MessageFmt:format(#data, data))
	if not result then
		if except == "closed" then                                                  --[[VERBOSE]] verbose:listen("client closed the connection")
			channel:close()
			result, except = true, nil
		else
			except = "LuDO protocol: socket error "..except
		end
	end
	return result, except
end

--------------------------------------------------------------------------------

function default(self, configs)
	return self.context.channels:default(configs)
end
