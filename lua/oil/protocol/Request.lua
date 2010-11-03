-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : 
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local select = _G.select

local table = require "table"
local unpack = table.unpack

local oo = require "oil.oo"
local class = oo.class



local Request = class()

function Request:getvalues()
	return unpack(self, 1, self.n)
end

function Request:setreply(success, ...)
	local count = select("#", ...)
	self.success = success
	self.n = count
	for i = 1, count do
		self[i] = select(i, ...)
	end
end

return Request
