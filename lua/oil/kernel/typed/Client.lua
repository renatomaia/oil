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
-- Release: 0.4                                                               --
-- Title  : Client-Side Broker                                                --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- broker:Facet
-- 	proxy:object fromstring(reference:string, [type:string])
-- 	proxy:object proxy(reference:table), [type:string]
-- 
-- proxies:Receptacle
-- 	proxy:object proxyto(reference:table, type)
-- 
-- references:Receptacle
-- 	reference:table decode(stringfiedref:string)
-- 
-- types:Receptacle
-- 	type:table resolve(type:string)
--------------------------------------------------------------------------------

local type = type

local oo     = require "oil.oo"
local assert = require "oil.assert"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.kernel.typed.Client", oo.class)

context = false

function fromstring(self, reference, type)
	return self:proxy(self.context.references:decode(reference), type)
end

function proxy(self, reference, type)                                      --[[VERBOSE]] verbose:client "creating proxy"
	return self.context.proxies:proxyto(reference,
		type and self.context.types:resolve(type))
end
