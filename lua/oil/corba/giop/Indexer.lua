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
-- Title  : CORBA Interface Indexer                                           --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- members:Receptacle
-- 	member:table valueof(interface:table, name:string)
--------------------------------------------------------------------------------

local oo      = require "oil.oo"
local giop    = require "oil.corba.giop"
local Indexer = require "oil.corba.idl.Indexer"                                 --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.giop.Indexer"

oo.class(_M, Indexer)

context = false

function valueof(self, interface, name)
	return Indexer.valueof(self, interface, name) or
	       giop.ObjectOperations[name]
end
