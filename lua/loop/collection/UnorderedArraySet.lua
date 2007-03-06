--------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## -----------------------
---------------------- ##      ##   ##  ##   ##  ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##      -----------------------
---------------------- ######   #####    #####   ##      -----------------------
----------------------                                   -----------------------
----------------------- Lua Object-Oriented Programming ------------------------
--------------------------------------------------------------------------------
-- Project: LOOP Class Library                                                --
-- Release: 2.2 alpha                                                         --
-- Title  : Unordered Array Optimized for Containment Check                   --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 29/10/2005 18:48                                                  --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   Can only store non-numeric values.                                       --
--   Storage of strings equal to the name of one method prevents its usage.   --
--------------------------------------------------------------------------------

local rawget = rawget
local oo     = require "loop.base"

module("loop.collection.UnorderedArraySet", oo.class)

valueat = rawget
indexof = rawget

function contains(self, value)
	return self[value] ~= nil
end

function add(self, value)
	self[#self+1] = value
	self[value] = #self
end

function remove(self, value)
	local size = #self
	local last = self[size]
	if value ~= last then
		local index = self[value]
		self[index], self[last] = last, index
	end
	self[value] = nil
	self[size] = nil
	return value
end

function removeat(self, index)
	return self:remove(self[index])
end
