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
-- Title  : Remote Object Invoker                                             --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- invoker:Facet
-- 	[results:object], [except:table] invoke(reference, operation, args...)
-- 
-- requester:Receptacle
-- 	channel:object getchannel(reference)
-- 	[request:table], [except:table], [requests:table] request(channel:object, reference, operation, args...)
-- 	[request:table], [except:table], [requests:table] getreply(channel:object, [probe:boolean])
-- 
-- mutex:Facet
-- 	locksend(channel:object)
-- 	releasesend(channel:object)
-- 	lockedreceive(channel:object, request:table, [probe:boolean])
-- 
-- tasks:Receptacle
-- 	current:thread
-- 	suspend()
-- 	resume(thread:thread)
-- 	register(thread:thread)
--------------------------------------------------------------------------------

local ipairs = ipairs
local next   = next
local select = select

local ObjectCache = require "loop.collection.ObjectCache"
local OrderedSet  = require "loop.collection.OrderedSet"

local oo     = require "oil.oo"
local assert = require "oil.assert"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.cooperative.Mutex", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function newlock()
	return { senders = OrderedSet(), receivers = {} }
end

function __init(self, object)
	self = oo.rawnew(self, object)
	self.locks = ObjectCache{ retrieve = newlock }
	return self
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function setfailed(self, channel, requests, except)
	local tasks = self.context.tasks
	local lock = self.locks[channel]
	for _, request in ipairs(requests) do
		request.success = false
		request.resultcount = 1
		request[1] = except
		local thread = lock[request]
		if thread then
			tasks:resume(thread)
		end
	end
end

function locksend(self, channel)
	local tasks = self.context.tasks
	local lock = self.locks[channel]
	if lock.sending then                                                          --[[VERBOSE]] verbose:mutex(true, "channel being used, waiting notification")
		lock.senders:enqueue(tasks.current)
		tasks:suspend()                                                             --[[VERBOSE]] verbose:mutex(false, "notification received")
	else                                                                          --[[VERBOSE]] verbose:mutex "channel free for sending"
		lock.sending = true
	end
end

function freesend(self, channel)
	local tasks = self.context.tasks
	local lock = self.locks[channel]
	if lock.senders:empty() then
		lock.sending = false                                                        --[[VERBOSE]] verbose:mutex "releasing send lock"
	else                                                                          --[[VERBOSE]] verbose:mutex "resuming sending thread"
		tasks:resume(lock.senders:dequeue())
	end
end

function lockreceive(self, channel, key)
	local tasks = self.context.tasks
	local lock = self.locks[channel]
	if lock.receiving then                                                        --[[VERBOSE]] verbose:mutex(true, "channel being used, waiting notification")
		key = key or #lock.receivers+1
		lock.receivers[key] = tasks.current
		tasks:suspend()                                                             --[[VERBOSE]] verbose:mutex(false, "notification received")
		lock.receivers[key] = nil
	else                                                                          --[[VERBOSE]] verbose:mutex "channel free for receiving"
		lock.receiving = tasks.current
	end
	return lock.receiving == tasks.current
end

function notifyreceived(self, channel, key)
	local thread = self.locks[channel].receivers[key]
	if thread then
		return self.context.tasks:resume(thread)
	end
end

function freereceive(self, channel)
	local tasks = self.context.tasks
	local lock = self.locks[channel]
	local thread = select(2, next(lock.receivers))
	if thread then                                                                --[[VERBOSE]] verbose:mutex "resuming sending thread"
		lock.receiving = thread
		tasks:register(thread)
	else
		lock.receiving = false                                                      --[[VERBOSE]] verbose:mutex "releasing receive lock"
	end
end
