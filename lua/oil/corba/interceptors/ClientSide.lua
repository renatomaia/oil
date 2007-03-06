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
-- Release: 0.4 alpha                                                         --
-- Title  : Client-side CORBA GIOP Protocol                                   --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------

local select = select
local unpack = unpack

local oo   = require "oil.oo"
local giop = require "oil.corba.giop"                                           --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.interceptors.ClientSide", oo.class)

--------------------------------------------------------------------------------

local RequestID = giop.RequestID
local ReplyID   = giop.ReplyID

--------------------------------------------------------------------------------

CanceledRequest = oo.class()

function CanceledRequest:ready()
	return true
end

function CanceledRequest:results()
	return self.success, unpack(self, 1, self.resultcount)
end

function handlerequest(self, request, object, success, ...)
	if request.cancelled then
		request.cancel = true
		return CanceledRequest{
			success = success,
			resultcount = select("#", ...),
			...,
		}
	end
	return object, success, ...
end

function handlereply(self, reply, success, ...)
	reply.success = success
	reply.resultcount = select("#", ...)
	for i = 1, reply.resultcount do
		reply[i] = select(i, ...)
	end
	return reply, ...
end

function before(self, request, object, ...)
	if request.port == "requests" then
		if request.method == request.object.newrequest then
			local interceptor = self.interceptor
			if interceptor.sendrequest then
				local channel, reference, operation = ...
				request.object_key        = reference._object
				request.operation         = operation.name
				request.response_expected = not operation.oneway
				self.message = request
				return self:handlerequest(request,
					object, channel, reference, operation,
					interceptor:sendrequest(request, select(4, ...)))
			else
				self.message = nil
			end
		end
	elseif request.port == "messenger" then
		if request.method == request.object.sendmsg then
			local type, header = select(2, ...)
			if type == RequestID and self.message then
				local message = self.message
				if message.service_context then
					header.service_context = message.service_context
				end
				if message.requesting_principal then
					header.requesting_principal = message.requesting_principal
				end
				self.message = nil
			end
		end
	end
	return object, ...
end

function after(self, request, ...)
	if request.port == "messenger" then
		if request.method == request.object.receivemsg then
			local type, message = ...
			if type == ReplyID then
				if self.interceptor.receivereply then
					self.message = message
				else
					self.message = nil
				end
			end
		end
	elseif request.port == "requests" then
		if request.method == request.object.newrequest then
			local reply = ...
			if reply then
				reply.message = request
			end
		elseif request.method == request.object.getreply then
			local interceptor = self.interceptor
			if interceptor.receivereply and self.message then
				reply = ...
				if reply then
					local message = self.message
					reply.message.service_context = message.service_context
					reply.message.request_id      = message.request_id
					reply.message.reply_status    = message.reply_status
					
					return self:handlereply(reply,
						interceptor:receivereply(
							reply.message,
							reply.success,
							unpack(reply, 1, reply.resultcount)
						)
					)
				end
				self.message = nil
			end
		end
	end
	return ...
end
