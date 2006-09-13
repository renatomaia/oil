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
-- Title  : Event factory for the Event Service                               --
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   create                                                                   --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local require   = require
local oo        = require "loop.base"

module("oil.cos.event.Factory", oo.class)                                       --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local os              = require "os"
local oo              = require "loop.base"
local assert          = require "oil.assert"
local Properties      = require "oil.properties"

--------------------------------------------------------------------------------
-- Key constants ---------------------------------------------------------------

local PROPS   = "PROPS"
local DATA    = "DATA"
local CREATED = "CREATED"

--------------------------------------------------------------------------------
-- Configuration properties ----------------------------------------------------

--------------------------------------------------------------------------------
-- Factory implementation ------------------------------------------------------

-- @param props table [optional] Configuration properties.

function __init(self, props)                                                    --[[VERBOSE]] verbose.server({"EventFactory:__init ", "entering"})
    return oo.rawnew(self, {
                            [PROPS] = props,
                           })
end

-- @param data table CORBA Any that contains generic event data.

function create(self, data)                                                     --[[VERBOSE]] verbose.server({"EventFactory:create ", "entering"})
    return {
            [CREATED] = os.time(),
            [DATA] = data,
           }
end

