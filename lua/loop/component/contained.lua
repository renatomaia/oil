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

local oo          = require "loop.cached"
local base        = require "loop.component.wrapped"

module("loop.component.contained", package.seeall)

--------------------------------------------------------------------------------

BaseTemplate = oo.class({}, base.BaseTemplate)

function BaseTemplate:__new(...)
	local comp = self.__component or self[1]
	if comp then comp = comp(...) end
	local state = {
		__component = comp,
		__factory = self,
	}
	for port, class in pairs(self) do
		if type(port) == "string" and port:match("^%a[%w_]*$") then
			state[port] = class(comp and comp[port], comp)
		end
	end
	return state
end

function Template(template, ...)
	if select("#", ...) > 0
		then return oo.class(template, ...)
		else return oo.class(template, BaseTemplate)
	end
end

--------------------------------------------------------------------------------

factoryof  = base.factoryof
templateof = base.templateof
ports      = base.ports
segmentof  = base.segmentof
