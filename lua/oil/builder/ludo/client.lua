local base = require "oil.arch.basic.common"
local arch = require "oil.arch.ludo.client"

return {
	ClientChannels = base.SocketChannels{ require "oil.kernel.base.Connector" },
	OperationRequester = arch.OperationRequester{ require "oil.ludo.Requester" },
}
