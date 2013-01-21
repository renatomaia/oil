local arch = require "oil.arch.typed.server"

return {
	ServantManager = arch.ServantManager{require "oil.kernel.typed.Servants",
		dispatcher = require "oil.kernel.typed.Dispatcher",
	},
}
