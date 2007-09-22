--------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## -----------------------
---------------------- ##      ##   ##  ##   ##  ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##      -----------------------
---------------------- ######   #####    #####   ##      -----------------------
----------------------                                   -----------------------
----------------------- Lua Object-Oriented Programming ------------------------
--------------------------------------------------------------------------------
-- Project: LOOP - Lua Object-Oriented Programming                            --
-- Release: 2.3 beta                                                          --
-- Title  : Component Model with Wrapping Container                           --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- Exported API:                                                              --
--   Template                                                                 --
--   factoryof(component)                                                     --
--   templateof(factory|component)                                            --
--   ports(template)                                                          --
--   segmentof(portname, component)                                           --
--------------------------------------------------------------------------------

local oo   = require "loop.cached"
local base = require "loop.component.base"

module("loop.component.wrapped", package.seeall)

--------------------------------------------------------------------------------

local ExternalState = oo.class()

function ExternalState:__index(name)
	self = self.__container
	local state = self.__state
	local port, manager = state[name], self[name]
	if port and manager
		then return rawget(manager, "__external") or manager
		else return port or state.__component[name]
	end
end

function ExternalState:__newindex(name, value)
	self = self.__container
	local state = self.__state
	local manager = self[name]
	if manager and manager.__bind then
		manager:__bind(value)
	elseif manager ~= nil then
		state[name] = value
	else
		state.__component[name] = value
	end
end

--------------------------------------------------------------------------------

BaseTemplate = oo.class({}, base.BaseTemplate)

function BaseTemplate:__container(segments)
	local container = {
		__state    = segments,
		__internal = segments,
	}
	container.__external = ExternalState{ __container = container }
	return container
end

function BaseTemplate:__build(segments)
	local container = self:__container(segments)
	local state = container.__state
	local context = container.__internal
	for port in pairs(self) do
		if port == 1
			then self:__setcontext(segments.__component, context)
			else self:__setcontext(segments[port], context)
		end
	end
	for port, class in oo.allmembers(oo.classof(self)) do
		if port:find("^%a") then
			container[port] = class(state, port, context, self)
		end
	end
	return container.__external
end

function Template(template, ...)
	if select("#", ...) > 0
		then return oo.class(template, ...)
		else return oo.class(template, BaseTemplate)
	end
end
--------------------------------------------------------------------------------

function factoryof(component)
	local container = component.__container
	return base.factoryof(container and container.__state or component)
end

function templateof(factory)
	if not oo.instanceof(factory, BaseTemplate) then
		factory = factoryof(factory)
	end
	return oo.classof(factory)
end

function ports(template)
	if not oo.subclassof(template, BaseTemplate) then
		template = templateof(template)
	end
	return base.ports(template)
end

function segmentof(comp, port)
	return comp.__container.__state[port]
end

--[[----------------------------------------------------------------------------
MyCompTemplate = comp.Template{
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
	[<portname>] = <PortClass>,
}

MyContainer = Container{
	__external = Handler{ <container> },
	__internal = {
		<componentimpl>,
		[<portname>] = <portimpl>,
		[<portname>] = <portimpl>,
		[<portname>] = <portimpl>,
	},
	[<portname>] = <portmanager>,
	[<portname>] = <portmanager>,
	[<portname>] = <portmanager>,
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
