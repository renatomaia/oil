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
-- Title  : Interoperable Object Reference (IOR) support                      --
-- Authors: Noemi Rodriquez       <noemi@inf.puc-rio.br>                      --
--          Roberto Ierusalimschy <roberto@inf.puc-rio.br>                    --
--          Renato Cerqueira      <rcerq@inf.puc-rio.br>                      --
--          Pedro Miller          <miller@inf.puc-rio.br>                     --
--          Reinaldo Mello        <rmello@inf.puc-rio.br>                     --
--          Luiz Nogara           <nogara@inf.puc-rio.br>                     --
--          Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   URLProtocols     List of protocols used to decode URL object references  --
--   encode(ior)      Encodes IOR to textual representation                   --
--   decode(string)   Decodes IOR from textual representation                 --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See section 13.6 of CORBA 3.0 specification.                             --
--   See section 13.6.10 of CORBA 3.0 specification for corbaloc.             --
--------------------------------------------------------------------------------

local require  = require
local tonumber = tonumber
local print = print
local ipairs = ipairs
local pairs = pairs

local string   = require "string"
local oo       = require "oil.oo"

module ("oil.corba.reference", oo.class)                                        --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local assert  = require "oil.assert"
local IDL     = require "oil.idl"

--------------------------------------------------------------------------------
-- String/byte conversions -----------------------------------------------------

local function byte2hexa(value)
	return (string.gsub(value, '(.)', function (char)
		-- TODO:[maia] check char to byte conversion
		return (string.format("%02x", string.byte(char)))
	end))
end

local function hexa2byte(value)
	local error
	value = (string.gsub(value, '(%x%x)', function (hexa)
		hexa = tonumber(hexa, 16)
		if hexa
			-- TODO:[maia] check byte to char conversion
			then return string.char(hexa)
			else error = true
		end
	end))
	if not error then return value end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Decoder = {}

function Decoder.IOR(reference, stream)                                         --[[VERBOSE]] verbose:ior(true, "using stringified IOR format")
	local buffer = reference.codec:newDecoder(hexa2byte(stream), true)
	local iortbl = buffer:IOR()
	return iortbl                                                                 --[[VERBOSE]] , verbose:ior(false)
end

function Decoder.corbaloc(reference, encoded)                                   --[[VERBOSE]] verbose:ior "using corbaloc IOR format"
	for token, data in string.gmatch(encoded, "(%w*):([^,]*)") do                 --[[VERBOSE]] verbose:ior("attempt to decode corbaloc with protocol '", token, "'")
		if reference.profile_resolver then                                               --[[VERBOSE]] verbose:ior(true, "using protocol '", token, "' to decode corbaloc")
			return {
				_type_id = "IDL:omg.org/CORBA/Object:1.0",
				-- TODO:[nogara] check this
				_profiles = { reference.profile_resolver:decodeurl(data) },
			}                                                                         --[[VERBOSE]] , verbose:ior(false)
		end
	end
	assert.illegal(encoded, "corbaloc, no supported protocol found", "INV_OBJREF")
end

--------------------------------------------------------------------------------
-- Coding ----------------------------------------------------------------------

function resolve(self, ...)                                                  --[[VERBOSE]] verbose:ior(true, "decode IOR")
	assert.type(arg[1], "string", "encoded IOR", "INV_OBJREF")
	local token, stream = string.match(arg[1], "^(%w+):(.+)$")                   --[[VERBOSE]] verbose:ior("got ", token, " IOR format")
	local decoder = Decoder[token]
	if not decoder then
		assert.illegal(token, "IOR format, currently not supported", "INV_OBJREF")
	end
	return decoder(self, stream)                                                        --[[VERBOSE]] , verbose:ior(false)
end

function encode(self, ...)                                                            --[[VERBOSE]] verbose:ior(true, "encode IOR")
	local buffer = self.codec:newEncoder(true)
	buffer:IOR(arg[1]) -- marshall IOR
	return "IOR:"..byte2hexa(buffer:getdata())                                    --[[VERBOSE]] , verbose:ior(false)
end

