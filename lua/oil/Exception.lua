local _G = require "_G"
local rawget = _G.rawget
local traceback = _G.debug and _G.debug.traceback -- only if available

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local Exception = require "loop.object.Exception"

local OiLException = class{
	"OiL Exception",
	__concat = Exception.__concat,
	__tostring = Exception.__tostring,
}

function OiLException:__new(except)
	self = rawnew(self, except)
	if self.traceback == nil and traceback ~= nil then
		self.traceback = traceback()
		self[1] = self[1].."\n$traceback"
	end
	return self
end

return OiLException
