local setfenv = setfenv

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch.base"

module "oil.arch.typed"

--
-- CLIENT SIDE
--

ClientBroker = component.Template({
	types = port.Receptacle--[[
		[type:table] resolve(type:string)
	]],
}, arch.ClientBroker)

ObjectProxies = component.Template({
	caches = port.Facet--[[
		setexcepthandler(interface|proxy:table, handler)
		resetfieldcache(interface|proxy:table)
	]],
	indexer = port.Receptacle--[[
		[interface:table] typeof(reference:table)
		operation, [value:function], [static:boolean] valueof(interface|reference:table, field:string)
	]],
}, arch.ObjectProxies)

--
-- SERVER SIDE
--

ServerBroker = component.Template({
	types = port.Receptacle--[[
		[type:table] resolve(type:string)
	]],
	mapper = port.Receptacle--[[
		???
	]],
}, arch.ServerBroker)

RequestDispatcher = component.Template({
	indexer = port.Receptacle--[[
		???
	]],
}, arch.RequestDispatcher)

--
-- TYPES
--

TypeRepository = component.Template{
	types = port.Facet--[[
		type:table register(definition:table)
		type:table remove(definition:table)
		type:table resolve(type:string)
	]],
}

function assemble(components)
	setfenv(1, components)
	--
	-- Client side
	--
	if ObjectProxies then
		ObjectProxies.indexer = ProxyIndexer.indexer
	end
	if ClientBroker and TypeRepository then
		ClientBroker.types = TypeRepository.types
	end
	--
	-- Server side
	--
	if RequestDispatcher then
		RequestDispatcher.indexer = ServantIndexer.indexer
	end
	if ServerBroker then
		ServerBroker.mapper = ServantIndexer.mapper
		if TypeRepository then
			ServerBroker.types = TypeRepository.types
		end
	end
end
