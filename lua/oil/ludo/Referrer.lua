--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua                                                  --
-- Release: 0.4                                                               --
-- Title  : Client-side CORBA GIOP Protocol specific to IIOP                  --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- references:Facet
-- 	reference:table referenceto(objectkey:string, accesspointinfo:table...)
-- 	reference:string encode(reference:table)
-- 	reference:table decode(reference:string)
--------------------------------------------------------------------------------

local tonumber = tonumber

local socket = require "socket.core"

local oo = require "oil.oo"                                                     --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.ludo.Referrer", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function referenceto(self, objectkey, accessinfo)
	local host = accessinfo.host
	if host == "*" then
		host = socket.dns.gethostname()
		host = socket.dns.toip(host) or host
	end
	return {
		host = host,
		port = accessinfo.port,
		object = objectkey,
	}
end

local ReferenceFrm = "@%s:%d"
function encode(self, reference)
	local object, host, port = reference.object, reference.host, reference.port
	if object ~= nil and host ~= nil and port ~= nil then
		return object..ReferenceFrm:format(host, port)
	end
	return nil, "bad LuDO reference"
end

local ReferencePat = "^([^@]+)@([^:]+):(%d+)$"
function decode(self, reference)
	local object, host, port = reference:match(ReferencePat)
	port = tonumber(port)
	if object ~= nil and host ~= nil and port ~= nil then
		return {
			host = host,
			port = port,
			object = object,
		}
	end
	return nil, "invalid LuDO reference"
end
