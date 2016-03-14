local LRUCache = require "loop.collection.LRUCache"

local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"                                       --[[VERBOSE]] local verbose = require "oil.verbose"


local Reservation = class()

function Reservation:cancel()
	self.manager.reserved = self.manager.reserved-1
end

function Reservation:set(channel)
	self:cancel()
	self.manager:add(channel)
end


local function discardOne(self)
	local found
	for conn in self.inuse:usedkeys(true) do
		if conn:idle() then
			found = conn
		--	if conn.listener == nil then break end
		--elseif found ~= nil then
			break
		end
	end
	if found ~= nil then
		found:close()
		return true
	end
end


local Limiter = class{ reserved = 0 }

function Limiter:__init()
	self.inuse = LRUCache{ maxsize = 1000 }
end

function Limiter:add(channel)
	channel.limiter = self
	self.inuse:put(channel)
end

function Limiter:remove(channel)
	channel.limiter = nil
	return self.inuse:remove(channel)
end

function Limiter:reserve()
	local inuse = self.inuse
	if inuse.size + self.reserved == inuse.maxsize then
		if not discardOne(self) then
			return nil, Exception{
				"channel limit reached, too many active channels",
				error = "badsocket",
			}
		end
	end
	self.reserved = self.reserved+1
	return Reservation{ manager = self }
end

return Limiter
