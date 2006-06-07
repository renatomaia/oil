-------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  ----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## ----------------------
---------------------- ##      ##   ##  ##   ##  ######  ----------------------
---------------------- ##      ##   ##  ##   ##  ##      ----------------------
---------------------- ######   #####    #####   ##      ----------------------
----------------------                                   ----------------------
----------------------- Lua Object-Oriented Programming -----------------------
-------------------------------------------------------------------------------
-- Project: LOOP Collections - Object Collections Implemented in LOOP        --
-- Release: 1.0 alpha                                                        --
-- Title  : Unordered Array Optimized for Containment Check                  --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                --
-- Date   : 29/10/2005 18:48                                                 --
-------------------------------------------------------------------------------
-- Notes:                                                                    --
--   Can only store non-numeric values.                                      --
--   Storage of strings equal to the name of one method prevents its usage.  --
-------------------------------------------------------------------------------

local rawget         = rawget
local loop           = require "loop"
local oo             = require "loop.simple"
local UnorderedArray = require "loop.collection.UnorderedArray"

module("loop.collection.UnorderedArraySet",
	loop.define( oo.class({}, UnorderedArray) )
)

valueat = rawget
indexof = rawget

function contains(self, value)
	return self[value] ~= nil
end

function add(self, value)
	UnorderedArray.add(self, value)
	self[value] = size(self)
end

function remove(self, value)
	removeat(self, self[value])
end

function removeat(self, index)
	self[ self[index] ] = nil
	return UnorderedArray.remove(self, index)
end