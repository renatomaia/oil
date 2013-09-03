local base = require "oil.arch.basic.common"
local arch = require "oil.arch.corba.server"

return {
	ServerChannels = base.SocketChannels { require "oil.kernel.base.Acceptor" },
	RequestListener = arch.RequestListener{ require "oil.corba.giop.Listener" },
}
