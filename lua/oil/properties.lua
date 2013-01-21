-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Properties management package for OiL
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>

local _G = require "_G"
local require = _G.require
local rawget = _G.rawget
local rawset = _G.rawset

local oo = require "loop.base"

local Properties = oo.class()

--------------------------------------------------------------------------------
-- Key constants ---------------------------------------------------------------

local PARENT = {}
local DEFAULT = {}

--------------------------------------------------------------------------------
-- Properties implementation ---------------------------------------------------

function Properties:__index(key)
    if key then
        local parent = rawget(self, PARENT)
        local default = rawget(self, DEFAULT)
        local value = parent and parent[key] or default and default[key] or nil
        rawset(self, key, value)
        return value
    else
        return nil
    end
end

function Properties:__new(parent, default)
    return oo.rawnew(self, {[PARENT] = parent,
                            [DEFAULT]= default})
end

return Properties
