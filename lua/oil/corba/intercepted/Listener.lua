local _G = require "_G"
local error = _G.error
local unpack = _G.unpack

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local class = oo.class

local giop = require "oil.corba.giop"
local IOR = giop.IOR

local Request = require "oil.protocol.Request"

local Listener = require "oil.corba.giop.Listener"
local ListenerRequest = Listener.Request


local ServerRequest = class({}, ListenerRequest)

local function donothing() end
function ServerRequest:preinvoke(entry, member)
	local object, method = ListenerRequest.preinvoke(self, entry, member)
	local interceptor = self.interceptor
	if interceptor then
		local intercepted = {
			service_context   = self.service_context,
			request_id        = self.request_id,
			response_expected = self.sync_scope ~= "channel",
			sync_scope        = self.sync_scope,
			object_key        = self.object_key,
			operation_name    = self.operation,
			servant           = object,
			operation         = member,
			interface         = member and member.defined_in,
			parameters        = member and {n=self.n,self:getvalues()} or nil,
			method            = method,
		}
		self.intercepted = intercepted
		if interceptor.receiverequest then                                          --[[VERBOSE]] verbose:interceptors(true, "intercepting request marshaling")
			interceptor:receiverequest(intercepted)
			local success = intercepted.success
			if success ~= nil then                                                    --[[VERBOSE]] verbose:interceptors("intercepted request was canceled")
				self.intercepted = nil -- this should cancel the reply interception
				local results = intercepted.results or {}
				if success then -- dispath should do 'unpack(results, 1, results.n or #results)'
					method, object = unpack, results
					self.n, self[1], self[2] = 2, 1, results.n or #results
				else -- dispath should do 'error(results[1])'
					method, object = error, results[1]
					self.n = 0
				end
			elseif intercepted.reference then                                 --[[VERBOSE]] verbose:interceptors("interceptor forwarded the request")
				self.forward_reference = intercepted.reference
				self.intercepted = nil -- this should cancel the reply interception
				method, object = donothing, true -- dispatch should do nothing
			else                                                                      --[[VERBOSE]] if intercepted.method~=method then verbose:interceptors("interceptor changed the invoked operation implementation") end
				method = intercepted.method
				local servant = intercepted.servant
				local parameters = intercepted.parameters
				-- uncancel if the interceptor provided target, method and parameters
				-- or update invoked object if it was changed
				if (object==nil and servant~=nil and method~=nil and parameters~=nil)
				or (object~=nil and servant~=object) then                               --[[VERBOSE]] verbose:interceptors("interceptor changed the invoked servant")
					object = servant
				end
				-- update parameter values
				if parameters then
					self.n = parameters.n or #parameters
					for i = 1, self.n do
						self[i] = parameters[i]
					end
				end
				-- update GIOP message fields
				self.service_context = intercepted.service_context
			end
		end
	end
	return object, method
end

local LocationForwardTypes = { IOR }
local function buildreply(self)
	local types, body
	local reference = self.forward_reference
	if reference then
		self.reply_status = "LOCATION_FORWARD"
		return LocationForwardTypes, { reference }
	end
	return ListenerRequest.getreplybody(self)
end
function ServerRequest:getreplybody()
	local types, body = buildreply(self)
	local intercepted = self.intercepted
	if intercepted then
		self.intercepted = nil
		local interceptor = self.interceptor
		if interceptor and interceptor.sendreply then
			intercepted.reply_status = self.reply_status
			intercepted.success = self.success
			if self.reply_status == "SYSTEM_EXCEPTION" then
				intercepted.results = {n=1, body[2]}
			else
				intercepted.results = {n=self.n, self:getvalues()}
			end                                                                       --[[VERBOSE]] verbose:interceptors(true, "intercepting reply marshaling")
			interceptor:sendreply(intercepted)                                        --[[VERBOSE]] verbose:interceptors(false, "interception ended")
			local reference = intercepted.reference
			if reference then
				self.forward_reference = reference
			else
				self.success = intercepted.success
				-- update returned values
				local results = intercepted.results or {}
				self.n = results.n or #results
				for i = 1, self.n do
					self[i] = results[i]
				end
			end
			-- update GIOP message fields
			types, body = buildreply(self)
			if intercepted.reply_service_context ~= nil then
				self.service_context = intercepted.reply_service_context
			end
		end
	end
	return types, body
end


local IceptedListener = class({}, Listener)

function IceptedListener:__init()
	self.Request = function(request)
		request.interceptor = self.interceptor
		return ServerRequest(request)
	end
end

return IceptedListener
