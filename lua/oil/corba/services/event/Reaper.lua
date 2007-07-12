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
-- Release: 0.4 alpha                                                         --
-- Title  : Reaper module for the Event Service                               --
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   run                                                                      --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local oil        = require "oil"
local oo         = require "oil.oo"
local Properties = require "oil.properties"
local Timer      = require "loop.thread.Timer"                                  --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.services.event.Reaper"

oo.class(_M, Timer)

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

--------------------------------------------------------------------------------
-- Configuration properties ----------------------------------------------------

-- @field PROP_INACTIVITY_TIMEOUT number Maximum number of seconds of
-- inactivity allowed for a proxy before it's disconnected. The default value
-- is 4 hours.
-- @field PROP_REAP_FREQUENCY number Frequency in seconds in which proxies
-- will be reaped. The default value is 30 minutes. The value 0 disables the
-- reaping of proxies.

PROP_REAP_FREQUENCY         = "oil.cos.event.reap_frequency"
PROP_MAX_INACTIVITY_TIMEOUT = "oil.cos.event.max_inactivity_timeout"

--------------------------------------------------------------------------------
-- Reaper implementation -------------------------------------------------------

-- @param props table [optional] Configuration properties.

function __init(self, props)
	local props = Properties(props, {
		[PROP_MAX_INACTIVITY_TIMEOUT] = 14400,
		[PROP_REAP_FREQUENCY]         = 5,
	})
	return Timer.__init(self, {
		scheduler = oil.tasks,
		rate = props[PROP_REAP_FREQUENCY],
		props = props,
	})
end

function action(self)
	-- TODO:[maciel] implement this!
end
