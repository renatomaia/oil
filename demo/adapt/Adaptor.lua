local error = error
local loadstring = loadstring
local pcall = pcall

local oo = require "oil.oo"
local oil = require "oil"

module("Adaptor", oo.class)

__type = "Adaptation::Adaptor"

function _M:__new(...)
	self = oo.rawnew(self, ...)
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

function _M:update(iface, impl)
	if iface ~= "" then
		self.orb:loadidl(iface)
	end
	if impl ~= "" then
		local result, errmsg = loadstring(impl)
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
