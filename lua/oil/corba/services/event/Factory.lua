--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.3 alpha                                                         --
-- Title  : Event factory for the Event Service                               --
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   create                                                                   --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local oo         = require "oil.oo"
local Properties = require "oil.properties"                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.services.event.Factory", oo.class)

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------


--------------------------------------------------------------------------------
-- Key constants ---------------------------------------------------------------

local PROPS   = "PROPS"
local DATA    = "DATA"

--------------------------------------------------------------------------------
-- Configuration properties ----------------------------------------------------

--------------------------------------------------------------------------------
-- Factory implementation ------------------------------------------------------

-- @param props table [optional] Configuration properties.

function __init(self, props)                                                    --[[VERBOSE]] verbose:cos_event"EventFactory:__init entering"
    return oo.rawnew(self, {
                            [PROPS] = props,
                           })
end

-- @param data table CORBA Any that contains generic event data.

function create(self, data)                                                     --[[VERBOSE]] verbose:cos_event "EventFactory:create entering"
    return {
            [DATA] = data,
           }
end
