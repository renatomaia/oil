
local require  = require
local tonumber = tonumber
local print = print
local pairs = pairs
local table = table

local string   = require "string"
local oo       = require "oil.oo"

module ("oil.dummy.reference", oo.class)                                        --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local assert  = require "oil.assert"

function resolve(self, profile)
	local host, port, object_key = string.match(profile, '.-:(.-),(.-),(.*)')
	profile = {host = host, port = port, object_key = object_key }
	return profile                                                                
end

function referto(self, ...)
-- args are (host, port, object_key)
	local servant = arg[1]
  return table.concat{ 'DUMMY:', servant._host, ',', servant._port, ',', servant._objectid }
end

