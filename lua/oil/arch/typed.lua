local setfenv = setfenv

local port      = require "oil.port"
local component = require "oil.component"
local arch      = require "oil.arch.base"

module "oil.arch.typed"

--
-- CLIENT SIDE
--

ClientBroker = component.Type({
	types = port.Receptacle--[[
		[type:table] resolve(type:string)
	]],
}, arch.ClientBroker)

ObjectProxies = component.Type({
	caches = port.Facet--[[
		setexcepthandler(interface|proxy:table, handler)
		resetfieldcache(interface|proxy:table)
	]],
	indexer = port.Receptacle--[[
		[interface:table] interfaceof(reference:table)
		operation, [value:function], [static:boolean] valueof(interface|reference:table, field:string)
	]],
}, arch.ObjectProxies)

--
-- SERVER SIDE
--

ServerBroker = component.Type({
	types = port.Receptacle--[[
		[type:table] resolve(type:string)
	]],
	mapper = port.Receptacle--[[
		???
	]],
}, arch.ServerBroker)

RequestDispatcher = component.Type({
	indexer = port.Receptacle--[[
		???
	]],
}, arch.RequestDispatcher)

function assemble(components)
	setfenv(1, components)
	--
	-- Client side
	--
	if ObjectProxies then
		ObjectProxies.indexer = ProxyIndexer.indexer
		if TypeRepository then
			TypeRepository.observers:__bind(ObjectProxies.caches)
		end
	end
	if ClientBroker then
		ClientBroker.types = TypeRepository and
		                   ( TypeRepository.importer or
		                     TypeRepository.types )
	end
	--
	-- Server side
	--
	if RequestDispatcher then
		RequestDispatcher.indexer = ServantIndexer.indexer
	end
	if ServerBroker then
		ServerBroker.mapper = ServantIndexer.mapper
		ServerBroker.types = TypeRepository and
		                   ( TypeRepository.importer or
		                     TypeRepository.types )
	end
end
