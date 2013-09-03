local arch = require "oil.arch.basic.server"

return {
	ServantManager = arch.ServantManager { require "oil.kernel.base.Servants",
		dispatcher = require "oil.kernel.lua.Dispatcher",
	},
}
