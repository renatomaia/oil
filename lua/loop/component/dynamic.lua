-------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  ----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## ----------------------
---------------------- ##      ##   ##  ##   ##  ######  ----------------------
---------------------- ##      ##   ##  ##   ##  ##      ----------------------
---------------------- ######   #####    #####   ##      ----------------------
----------------------                                   ----------------------
----------------------- Lua Object-Oriented Programming -----------------------
-------------------------------------------------------------------------------
-- Title  : LOOP - Lua Object-Oriented Programming                           --
-- Name   : Component Model with Interception                                --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                --
-- Version: 3.0 work1                                                        --
-- Date   : 22/2/2006 16:18                                                  --
-------------------------------------------------------------------------------
-- Exported API:                                                             --
--   Template                                                                    --
-------------------------------------------------------------------------------

local oo   = require "loop.cached"
local base = require "loop.component.contained"

module("loop.component.dynamic", package.seeall)

--------------------------------------------------------------------------------

local WeakTable = oo.class{ __mode = "k" }

--------------------------------------------------------------------------------

local DynamicPort = oo.class()

function DynamicPort:__call(state, name, ...)
	if self.class then
		state[name] = self.class(state[name], state.__component)
	end
	return self.port(state, name, ...)
end

function DynamicPort:__tostring()
	return self.name
end

--------------------------------------------------------------------------------

local InternalState = oo.class()

function InternalState:__index(name)
	self = self.__container
	local state = self.__state
	local port, manager = state[name], self[name]
	if manager == nil then
		local factory = state.__factory
		local class = factory[name]
		if oo.classof(class) == DynamicPort then
			local context = self.__internal
			self[class] = class(state, class, context)
			port, manager = state[class], self[class]
			factory:__setcontext(port, context)
		end
	end
	return port, manager
end

function InternalState:__newindex(name, value)
	self = self.__container
	local state = self.__state
	local manager = self[name]
	if manager == nil then
		local factory = state.__factory
		local class = factory[name]
		if oo.classof(class) == DynamicPort then
			local context = self.__internal
			self[class] = class(state, class, context)
			manager = self[class]
			factory:__setcontext(state[class], context)
		end
	end
	if manager and manager.__bind then
		manager:__bind(value)
	elseif manager ~= nil then
		state[name] = value
	else
		state.__component[name] = value
	end
end

--------------------------------------------------------------------------------

local ExternalState = oo.class({}, InternalState)

function ExternalState:__index(name)
	local port, manager = oo.superclass(ExternalState).__index(self, name)
	if port and manager
		then return rawget(manager, "__external") or manager
		else return port or self.__container.__state.__component[name]
	end
end

--------------------------------------------------------------------------------

BaseTemplate = oo.class({}, base.BaseTemplate)

function BaseTemplate:__container(comp)
	local container = WeakTable(base.BaseTemplate.__container(self, comp))
	container.__state = WeakTable(container.__state)
	container.__internal = InternalState{ __container = container }
	container.__external = ExternalState{ __container = container }
	return container
end

function Template(template, ...)
	if select("#", ...) > 0
		then return oo.class(template, ...)
		else return oo.class(template, BaseTemplate)
	end
end

--------------------------------------------------------------------------------

factoryof = base.factoryof
templateof = base.templateof

local function portiterator(container, name)
	local factory = container.__state.__factory
	local port = factory[name]
	if oo.classof(port) == DynamicPort then
		name = port
	end
	repeat
		name = next(container, name)
		if name == nil then
			return nil
		elseif oo.classof(name) == DynamicPort then
			return name.name, name.port
		end
	until name:find("^%a")
	return name, oo.classof(factory)[name]
end

function ports(component)
	local container = component.__container
	if container
		then return portiterator, container
		else return base.port(component)
	end
end

function segmentof(comp, name)
	local state = comp.container.__state
	local port = state.__factory[name]
	if oo.classof(port) == DynamicPort then
		name = port
	end
	return state[port]
end

--------------------------------------------------------------------------------

function addport(scope, name, port, class)
	if oo.isclass(scope) or oo.instanceof(scope, BaseTemplate) then
		scope[name] = DynamicPort{
			name = name,
			port = port,
			class = class,
		}
	else
		local container = scope.__container
		if container then
			local context = container.__internal
			local state = container.__state
			local factory = state.__factory
			if class then
				local comp = state.__component
				state[name] = class(comp[name], comp)
			end
			container[name] = port(state, name, context, factory)
			factory:__setcontext(state[name], context)
		end
	end
end

function removeport(scope, name)
	if oo.isclass(scope) or oo.instanceof(scope, BaseTemplate) then
		scope[name] = nil
	else
		local container = scope.__container
		if container then
			local state = container.__state
			container[name] = nil
			state[name] = nil
		end
	end
end

--[[----------------------------------------------------------------------------
MyCompTemplate = comp.Template{
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
}

MyContainer = WeakKeyTable{
	__external = Handler{ <container> },
	__internal = Context{ <container> },
	__state = WeakKeyTable{
		<componentimpl>,
		[<portname>] = <portimpl>,
		[<portname>] = <portimpl>,
		[<dynaport>] = <portimpl>,
	},
	__factory = {
		[<portname>] = <portclass>,
		[<portname>] = <portclass>,
		[<portname>] = <dynaport>,
	},
	[<portname>] = <portmanager>,
	[<portname>] = <portmanager>,
	[<dynaport>] = <portmanager>,
}

EMPTY       Internal Self      |   EMPTY       Internal Self   
Facet       nil      wrapper   |   Facet       nil      nil
Receptacle  nil      wrapper   |   Receptacle  nil      nil
Multiple    multiple wrapper   |   Multiple    multiple nil
                               |                              
FILLED      Internal Self      |   FILLED      Internal Self   
Facet       port     wrapper   |   Facet       port     nil
Receptacle  wrapper  wrapper   |   Receptacle  port     nil
Multiple    multiple wrapper   |   Multiple    multiple nil
----------------------------------------------------------------------------]]--
