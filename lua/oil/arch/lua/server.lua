local arch = require "oil.arch"

module "oil.arch.lua.server"

function assemble(components)
	arch.start(components)
	LuaEncoder.servants = ServantManager.servants
	arch.finish(components)
end
