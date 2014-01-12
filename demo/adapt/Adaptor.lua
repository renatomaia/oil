local _G = require "_G"
local error = _G.error
local load = _G.load
local pcall = _G.pcall

local oo = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local Adaptor = class{
	__type = "Adaptation::Adaptor",
}

function Adaptor:__new(...)
	self = rawnew(self, ...)
	if self.orb.types:resolve("Adaptation::Adaptor") == nil then
		self.orb:loadidl[[
			module Adaptation {
				exception CodeError { string message; };
				exception RuntimeError { string message; };
				interface Adaptor {
					void update(in string iface, in string impl)
						raises (CodeError, RuntimeError);
				};
			};
		]]
	end
	return self.orb:newservant(self)
end

function Adaptor:update(iface, impl)
	if iface ~= "" then
		self.orb:loadidl(iface)
	end
	if impl ~= "" then
		local result, errmsg = load(impl)
		if not result then
			error(self.orb:newexcept{"Adaptation::CodeError",
				message=errmsg
			})
		end
		result, errmsg = pcall(result, self.object, self.orb)
		if not result then
			error(self.orb:newexcept{"Adaptation::RuntimeError",
				message=errmsg
			})
		end
		-- TODO: if errmsg then self.servant:__settype(errmsg) end
	end
end

return Adaptor
