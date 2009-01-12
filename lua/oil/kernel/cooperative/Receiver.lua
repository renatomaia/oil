--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.4                                                               --
-- Title  : Request Acceptor                                                  --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- acceptor:Facet
-- 	configs:table, [except:table] setupaccess([configs:table])
-- 	success:boolean, [except:table] hasrequest(configs:table)
-- 	success:boolean, [except:table] acceptone(configs:table)
-- 	success:boolean, [except:table] acceptall(configs:table)
-- 	success:boolean, [except:table] halt(configs:table)
-- 
-- listener:Receptacle
-- 	configs:table default([configs:table])
-- 	channel:object, [except:table] getchannel(configs:table)
-- 	success:boolean, [except:table] freeaccess(configs:table)
-- 	success:boolean, [except:table] freeachannel(channel:object)
-- 	request:table, [except:table] = getrequest(channel:object, [probe:boolean])
-- 	success:booelan, [except:table] = sendreply(request:table, success:booelan, results...)
-- 
-- dispatcher:Receptacle
-- 	success:boolean, [except:table]|results... dispatch(objectkey:string, operation:string|function, params...)
-- 
-- tasks:Receptacle
-- 	current:thread
-- 	start(func:function, args...)
-- 	remove(thread:thread)
--------------------------------------------------------------------------------

local next  = next
local pairs = pairs

local oo        = require "oil.oo"
local Exception = require "oil.Exception"
local Receiver  = require "oil.kernel.base.Receiver"                            --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.cooperative.Receiver"

oo.class(_M, Receiver)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function __init(self, object)
	self = oo.rawnew(self, object)
	self.thread = {}
	self.threads = {}
	return self
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function sendreply(self, request, ...)
	local context = self.context
	local result, except = context.listener:sendreply(request, ...)
	if not result and not self.except then
		self.except = except
	end
end

function dispatchrequest(self, channel, request)
	self:sendreply(request, self.context.dispatcher:dispatch(
		request.object_key,
		request.operation,
		request.opimpl,
		request:params()
	))
end

function getallrequests(self, accesspoint, channel)
	local context = self.context
	local thread = context.tasks.current
	local threads = self.threads[accesspoint]
	threads[thread] = channel
	local result, except
	repeat
		result, except = context.listener:getrequest(channel)
		if result then
			if result == true then
				break
			else
				context.tasks:start(self.dispatchrequest, self, channel, result)
			end
		elseif not self.except then
			self.except = except
			break
		end
	until self.except
	channel:release()
	threads[thread] = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function acceptall(self)
	local accesspoint = self.accesspoint                                          --[[VERBOSE]] verbose:acceptor(true, "accept all requests from channel ",accesspoint)
	local context = self.context
	self.thread[accesspoint] = context.tasks.current
	self.threads[accesspoint] = {}
	local result, except
	repeat
		result, except = context.listener:getchannel(accesspoint)
		if result then
			context.tasks:start(self.getallrequests, self, accesspoint, result)
		end
	until not result or self.except
	self.threads[accesspoint] = nil
	self.thread[accesspoint] = nil                                                --[[VERBOSE]] verbose:acceptor(false)
	return nil, self.except or except
end

function halt(self)                                                             --[[VERBOSE]] verbose:acceptor "halt acceptor"
	local tasks = self.context.tasks
	local listener = self.context.listener
	local result, except = nil, Exception{
		reason = "halted",
		message = "orb already halted",
	}
	local thread = self.thread[accesspoint]
	if thread then
		tasks:remove(thread)
		result, except = listener:freeaccess(accesspoint)
		self.thread[accesspoint] = nil
	end
	local threads = self.threads[accesspoint]
	if threads then
		for thread, channel in pairs(threads) do
			tasks:remove(thread)
			result, except = listener:freeachannel(channel)
		end
		self.threads[accesspoint] = nil
	end
	return result, except
end
