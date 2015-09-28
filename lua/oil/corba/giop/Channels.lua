local oo = require "oil.oo"
local class = oo.class

local Channel = require "oil.corba.giop.Channel"

local ChannelFactory = class()

function ChannelFactory:create(socket)
	return Channel{
		socket = socket,
		context = self,
	}
end

return ChannelFactory
