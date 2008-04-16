local setfenv = setfenv

local port      = require "oil.port"
local component = require "oil.component"

module "oil.arch.ludo"

--
-- COMMUNICATION
--
SocketChannels = component.Template{
	channels = port.Facet--[[
		channel:object retieve(configs:table)
		configs:table default(configs:table)
	]],
	sockets = port.Receptacle--[[
		socket:object tcp()
	]],
}

ValueEncoder = component.Template{
	codec = port.Facet--[[
		encoder:object encoder()
		decoder:object decoder(stream:string)
	]],
}

--
-- REFERENCES
--
ObjectReferrer = component.Template{
	references = port.Facet--[[
		reference:table referenceto(objectkey:string, accesspointinfo:table...)
		reference:string encode(reference:table)
		reference:table decode(reference:string)
	]],
}

--
-- REQUESTER
--

OperationRequester = component.Template{
	requests = port.Facet--[[
		channel:object getchannel(reference:table)
		reply:object, [except:table], [requests:table] newrequest(channel:object, reference:table, operation:table, args...)
		reply:object, [except:table], [requests:table] getreply(channel:object, [probe:boolean])
	]],
	channels = port.Receptacle--[[
		channel:object retieve(configs:table)
	]],
	codec = port.Receptacle--[[
		encoder:object encoder()
		decoder:object decoder(stream:string)
	]],
}

--
-- LISTENER
--
RequestListener = component.Template{
	listener = port.Facet--[[
		configs:table default([configs:table])
		channel:object, [except:table] getchannel(configs:table)
		request:object, [except:table], [requests:table] = getrequest(channel:object, [probe:boolean])
	]],
	channels = port.Receptacle--[[
		channel:object retieve(configs:table)
	]],
	codec = port.Receptacle--[[
		encoder:object encoder()
		decoder:object decoder(stream:string)
	]],
}

function assemble(components)
	setfenv(1, components)
	-- COMMUNICATION
	if ClientChannels then
		ClientChannels.sockets = BasicSystem.sockets
	end
	if ServerChannels then
		ServerChannels.sockets = BasicSystem.sockets
	end
	-- REQUESTER
	if OperationRequester then
		OperationRequester.codec = ValueEncoder.codec
		OperationRequester.channels = ClientChannels.channels
	end
	-- LISTENER
	if RequestListener then
		RequestListener.codec = ValueEncoder.codec
		RequestListener.channels = ServerChannels.channels
	end
end
