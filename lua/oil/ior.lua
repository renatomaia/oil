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

local string   = require "string"

module "oil.ior"                                                                --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local assert  = require "oil.assert"
local IDL     = require "oil.idl"
local cdr     = require "oil.cdr"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

URLProtocols = {}

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

function Decoder.IOR(stream)                                                    --[[VERBOSE]] verbose.ior("using stringified IOR format", true)
	local buffer = cdr.ReadBuffer(hexa2byte(stream), true)
	return buffer:IOR()                                                           --[[VERBOSE]] , verbose.ior()
end

function Decoder.corbaloc(encoded)                                              --[[VERBOSE]] verbose.ior "using corbaloc IOR format"
	for token, data in string.gmatch(encoded, "(%w*):([^,]*)") do                 --[[VERBOSE]] verbose.ior{"attempt to decote corbaloc with protocol '", token, "'"}
		local protocol = URLProtocols[token]
		if protocol then                                                            --[[VERBOSE]] verbose.ior({"using protocol '", token, "' to decode corbaloc"}, true)
			return {
				_type_id = "IDL:omg.org/CORBA/Object:1.0",
				_profiles = { protocol.decodeurl(data) },
			}                                                                         --[[VERBOSE]] , verbose.ior()
		end
	end
	assert.ilegal(encoded, "corbaloc, no supported protocol found", "INV_OBJREF")
end

--------------------------------------------------------------------------------
-- Coding ----------------------------------------------------------------------

function decode(encoded)                                                        --[[VERBOSE]] verbose.ior("decode IOR", true)
	assert.type(encoded, "string", "encoded IOR", "INV_OBJREF")
	local token, stream = string.match(encoded, "^(%w+):(.+)$")                   --[[VERBOSE]] verbose.ior{"got ", token, " IOR format"}
	local decoder = Decoder[token]
	if not decoder then
		assert.ilegal(token, "IOR format, currently not supported", "INV_OBJREF")
	end
	return decoder(stream)                                                        --[[VERBOSE]] , verbose.ior()
end

function encode(ior)                                                            --[[VERBOSE]] verbose.ior("encode IOR", true)
	local buffer = cdr.WriteBuffer(true)
	buffer:IOR(ior) -- marshall IOR
	return "IOR:"..byte2hexa(buffer:getdata())                                    --[[VERBOSE]] , verbose.ior()
end
