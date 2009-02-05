local oo    = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"
local utils = require "oil.kernel.base.Proxies.utils"

local assertresults = utils.assertresults
local unpackrequest = utils.unpackrequest

--------------------------------------------------------------------------------

local Request = oo.class()

function Request:ready()                                                        --[[VERBOSE]] verbose:proxies("check reply availability")
	local proxy = self.proxy
	assertresults(proxy, self.operation,
	              proxy.__context.requester:getreply(request, true))
	return self.success ~= nil
end

function Request:results()                                                      --[[VERBOSE]] verbose:proxies(true, "get reply results")
	local success, except = self.proxy.__context.requester:getreply(self)
	if success then
		return unpackrequest(self)
	end                                                                           --[[VERBOSE]] verbose:proxies(false)
	return success, except
end

function Request:evaluate()                                                     --[[VERBOSE]] verbose:proxies("get deferred results of ",self.operation)
	return assertresults(self.proxy, self.operation, self:results())
end

--------------------------------------------------------------------------------

local Failed = oo.class({}, Request)

function Failed:ready()
	return true
end

function Failed:results()
	return false, self[1]
end

--------------------------------------------------------------------------------

return function(invoker, operation)
	return function(self, ...)
		local request, except = invoker(self, ...)
		if request then
			request.proxy = self
			request.operation = operation
			request = Request(request)
		else
			request = Failed{ except }
		end
		return request
	end
end
