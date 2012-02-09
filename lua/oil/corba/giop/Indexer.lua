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
-- Release: 0.5                                                               --
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

local CurrentInterface

function giop.ObjectOperations._is_a:implementation(repid)
	local interface = CurrentInterface -- get current interface
	CurrentInterface = nil             -- clear current interface
	if interface then
		for base in interface:hierarchy() do
			if base.repID == repid then
				return true
			end
		end
	end
	return false
end

function giop.ObjectOperations._interface:implementation()
	local interface = CurrentInterface -- get current interface
	CurrentInterface = nil             -- clear current interface
	return interface
end

function giop.ObjectOperations._non_existent:implementation()
	return false
end

function giop.ObjectOperations._component:implementation()
	return nil
end

function valueof(self, interface, name)
	local member = Indexer.valueof(self, interface, name)
	if member == nil then
		CurrentInterface = interface -- setup current interface to be used by impls.
		member = giop.ObjectOperations[name]
	elseif member._type ~= "operation" then
		member = nil
	end
	return member
end
