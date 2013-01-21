local builder = require "oil.builder"
local create = builder.create

local arch = require "oil.arch.ludo.byref"

local factories = {
	LuaEncoder = arch.ValueEncoder{ require "oil.ludo.CodecByRef" },
}

function factories.create(built)
	create(factories, built)
	ValueEncoder = LuaEncoder -- make alias
end

return factories
