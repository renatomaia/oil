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
-- Name   : Base Component Model                                             --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                --
-- Version: 3.0 work1                                                        --
-- Date   : 22/2/2006 16:18                                                  --
-------------------------------------------------------------------------------
-- Exported API:                                                             --
--   Template                                                                    --
--   Facet                                                                   --
--   Receptacle                                                              --
--   ListReceptacle                                                          --
--   HashReceptacle                                                          --
--   SetReceptacle                                                           --
-------------------------------------------------------------------------------

local oo = require "loop.cached"

module("loop.component.base", package.seeall)

--------------------------------------------------------------------------------

BaseTemplate = oo.class()

function BaseTemplate:__call(...)
	return self:__build(self:__new(...))
end

function BaseTemplate:__new(...)
	local comp = self.__component or self[1]
	if comp then
		comp = comp(...)
		comp.__factory = self
		comp.__component = comp
	else
		comp = { __factory = self }
	end
	for port, class in pairs(self) do
		if type(port) == "string" and port:match("^%a[%w_]*$") then
			comp[port] = class(comp[port], comp)
		end
	end
	return comp
end

local function tryindex(segment) return segment.context end
function BaseTemplate:__setcontext(segment, context)
	local success, setcontext = pcall(tryindex, segment)
	if success and setcontext ~= nil then
		if type(setcontext) == "function"
			then setcontext(segment, context)
			else segment.context = context
		end
	end
end

function BaseTemplate:__build(segments)
	for port in pairs(self) do
		if port == 1
			then self:__setcontext(segments.__component, segments)
			else self:__setcontext(segments[port], segments)
		end
	end
	for port, class in oo.allmembers(oo.classof(self)) do
		if port:match("^%a") then
			class(segments, port, segments)
		end
	end
	return segments
end

function Template(template, ...)
	if select("#", ...) > 0
		then return oo.class(template, ...)
		else return oo.class(template, BaseTemplate)
	end
end

--------------------------------------------------------------------------------

function factoryof(component)
	return component.__factory
end

function templateof(object)
	return oo.classof(factoryof(object) or object)
end

local nextmember
local function portiterator(state, name)
	local port
	repeat
		name, port = nextmember(state, name)
		if name == nil then return end
	until name:find("^%a")
	return name, port
end
function ports(template)
	if not oo.subclassof(template, BaseTemplate) then
		template = templateof(template)
	end
	local state, var
	nextmember, state, var = oo.allmembers(template)
	return portiterator, state, var
end

function segmentof(comp, port)
	return comp[port]
end

--------------------------------------------------------------------------------

function Facet(segments, name)
	segments[name] = segments[name] or
	                 segments.__component[name] or
	                 segments.__component
	return false
end

--------------------------------------------------------------------------------

function Receptacle()
	return false
end

--------------------------------------------------------------------------------

MultipleReceptacle = oo.class{
	__all = pairs,
	__hasany = next,
	__get = rawget,
}

function MultipleReceptacle:__init(segments, name)
	local receptacle = oo.rawnew(self, segments[name])
	segments[name] = receptacle
	return receptacle
end

function MultipleReceptacle:__newindex(key, value)
	if value == nil
		then self:__unbind(key)
		else self:__bind(value, key)
	end
end

function MultipleReceptacle:__unbind(key)
	local port = rawget(self, key)
	rawset(self, key, nil)
	return port
end

--------------------------------------------------------------------------------

ListReceptacle = oo.class({}, MultipleReceptacle)

function ListReceptacle:__bind(port)
	local index = #self + 1
	rawset(self, index, port)
	return index
end

--------------------------------------------------------------------------------

HashReceptacle = oo.class({}, MultipleReceptacle)

function HashReceptacle:__bind(port, key)
	rawset(self, key, port)
	return key
end

--------------------------------------------------------------------------------

SetReceptacle = oo.class({}, MultipleReceptacle)

function SetReceptacle:__bind(port)
	rawset(self, port, port)
	return port
end

--------------------------------------------------------------------------------

_M[Facet         ] = "Facet"
_M[Receptacle    ] = "Receptacle"
_M[ListReceptacle] = "ListReceptacle"
_M[HashReceptacle] = "HashReceptacle"
_M[SetReceptacle ] = "SetReceptacle"
