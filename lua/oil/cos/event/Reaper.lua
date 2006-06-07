-- $Id$
--******************************************************************************
-- Copyright 2002 Noemi Rodriquez & Roberto Ierusalimschy. All rights reserved. 
--******************************************************************************

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
-- Title  : Reaper module for the Event Service                               --
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   run                                                                      --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local scheduler = scheduler
local require   = require
local loop      = require "loop"
local oo        = require "loop.base"

module("oil.cos.event.Reaper", loop.define(oo.class()))                         --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local os              = require "os"
local oo              = require "loop.base"
local assert          = require "oil.assert"
local Properties      = require "oil.properties"

--------------------------------------------------------------------------------
-- Configuration properties ----------------------------------------------------

-- @field PROP_INACTIVITY_TIMEOUT number Maximum number of seconds of
-- inactivity allowed for a proxy before it's disconnected. The default value
-- is 4 hours.
-- @field PROP_REAP_FREQUENCY number Frequency in seconds in which proxies
-- will be reaped. The default value is 30 minutes. The value 0 disables the
-- reaping of proxies.

PROP_REAP_FREQUENCY          = "oil.cos.event.reap_frequency"
PROP_MAX_INACTIVITY_TIMEOUT  = "oil.cos.event.max_inactivity_timeout"

--------------------------------------------------------------------------------
-- Reaper implementation -------------------------------------------------------

-- @param props table [optional] Configuration properties.

function __init(self, props)                                                    --[[VERBOSE]] verbose.server({"EventReaper:__init ", "entering ", scheduler:current()})
    local props = Properties(props, {
                                     [PROP_MAX_INACTIVITY_TIMEOUT]  = 14400,
                                     [PROP_REAP_FREQUENCY]          = 5,
                                    })
    return oo.rawnew(self, {
                            props = props,
                           })
end

function run(self)                                                              --[[VERBOSE]] verbose.server({"EventReaper:run ", "entering ", scheduler:current()})
    self.thread = scheduler:current()
    while self.thread do                                                        --[[VERBOSE]] verbose.server({"EventReaper:run ", "loop ", scheduler:current()})
                                                                                --[[VERBOSE]] verbose.server({"EventReaper:run ", "sleeping ", scheduler:current()})
        scheduler.sleep(self.props[PROP_REAP_FREQUENCY])                        --[[VERBOSE]] verbose.server({"EventReaper:run ", "awaking ", scheduler:current()})
    end                                                                         --[[VERBOSE]] verbose.server({"EventReaper:run ", "leaving ", scheduler:current()})
end

function destroy(self)                                                          --[[VERBOSE]] verbose.server({"EventReaper:destroy ", "entering ", self.thread})
    self.thread = nil
end

