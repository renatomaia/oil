
local require  = require
local tonumber = tonumber
local print = print
local pairs = pairs

local string   = require "string"
local oo       = require "oil.oo"

module ("oil.dummy.reference", oo.class)                                        --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local assert  = require "oil.assert"

function decode_profile(self, profile)
	local host, port, object_key = string.match(profile, '.-:(.-),(.-),(.*)')
	profile = {host = host, port = port, object_key = object_key }
	return profile                                                                
end

function encode_profile(self, ...)
-- args are (host, port, object_key)
  return table.concat{ 'DUMMY:', arg[1], ',', arg[2], ',', arg[3] }
end

