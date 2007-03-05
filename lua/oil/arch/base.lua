local setfenv = setfenv

local port      = require "oil.port"
local component = require "oil.component"

module "oil.arch.base"

OperatingSystem = component.Type{
	sockets = port.Facet--[[
	]],
}

--
-- CLIENT SIDE
--

ClientBroker = component.Type{
	broker = port.Facet--[[
		proxy:object fromstring(reference:string, [interface:string])
	]],
	proxies = port.Receptacle--[[
		proxy:object proxyto(reference:table, [interface:table])
	]],
	references = port.Receptacle--[[
		reference:table decode(reference:string)
	]],
}

ObjectProxies = component.Type{
	proxies = port.Facet--[[
		proxy:object proxyto(reference:table, [interface:table])
	]],
	invoker = port.Receptacle--[[
		[results:object], [except:table] invoke(reference:table, operation, args...)
	]],
}

OperationInvoker = component.Type{
	invoker = port.Facet--[[
		[results:object], [except:table] invoke(reference:table, operation, args...)
	]],
	requester = port.Receptacle--[[
		channel:object getchannel(reference:table)
		[request:table], [except:table], [requests:table] request(channel:object, reference:table, operation, args...)
		[request:table], [except:table], [requests:table] getreply(channel:object, [probe:boolean])
	]],
}

--
-- SERVER SIDE
--

ServerBroker = component.Type{
	broker = port.Facet--[[
		[configs:table], [except:table] initialize([configs:table])
		servant:object object(impl:object, [objectkey:string], [interface:string])
		reference:string tostring(servant:object)
		success:boolean, [except:table] pending()
		success:boolean, [except:table] step()
		success:boolean, [except:table] run()
		success:boolean, [except:table] shutdown()
	]],
	objects = port.Receptacle--[[
		servant:object register(impl:object, objectkey:string)
		impl:object unregister(servant:object)
	]],
	acceptor = port.Receptacle--[[
		configs:table, [except:table] setup([configs:table])
		success:boolean, [except:table] hasrequest(configs:table)
		success:boolean, [except:table] acceptone(configs:table)
		success:boolean, [except:table] acceptall(configs:table)
		success:boolean, [except:table] halt()
	]],
	references = port.Receptacle--[[
		reference:table referenceto(objectkey:string, accesspointinfo:table...)
		reference:string encode(reference:table)
		reference:table decode(reference:string)
	]],
}

RequestDispatcher = component.Type{
	objects = port.Facet--[[
		servant:object register(impl:object, objectkey:string)
		impl:object unregister(servant:object)
	]],
	dispatcher = port.Facet--[[
		dispatch(request)
	]],
}

RequestReceiver = component.Type{
	acceptor = port.Facet--[[
		success:boolean, [except:table] hasrequest()
		success:boolean, [except:table] acceptone()
		success:boolean, [except:table] acceptall()
	]],
	dispatcher = port.Receptacle--[[
		dispatch(request)
	]],
	listener = port.Receptacle--[[
		channel:object, [except:table] getchannel(configs:table)
		request:object, [except:table], [requests:table] = getrequest(channel:object, [probe:boolean])
	]],
}

function assemble(components)
	setfenv(1, components)
	--
	-- Client side
	--
	if OperationInvoker then
		OperationInvoker.requester = OperationRequester.requests
	end
	if ObjectProxies then
		ObjectProxies.invoker = OperationInvoker.invoker
	end
	if ClientBroker then
		ClientBroker.proxies = ObjectProxies.proxies
		ClientBroker.references = ObjectReferrer.references
	end
	--
	-- Server side
	--
	if RequestReceiver then
		RequestReceiver.listener = RequestListener.listener
		RequestReceiver.dispatcher = RequestDispatcher.dispatcher
	end
	if ServerBroker then
		ServerBroker.objects = RequestDispatcher.dispatcher
		ServerBroker.acceptor = RequestReceiver.acceptor
		ServerBroker.references = ObjectReferrer.references
	end
end
