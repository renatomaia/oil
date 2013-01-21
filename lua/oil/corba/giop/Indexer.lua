-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : CORBA Interface Indexer
-- Authors: Renato Maia <maia@inf.puc-rio.br>

local oo = require "oil.oo"
local giop = require "oil.corba.giop"
local IDLIndexer = require "oil.corba.idl.Indexer"

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


local Indexer = oo.class({}, IDLIndexer)

function Indexer:valueof(interface, name)
	local member = IDLIndexer.valueof(self, interface, name)
	if member == nil then
		CurrentInterface = interface -- setup current interface to be used by impls.
		member = giop.ObjectOperations[name]
	elseif member._type ~= "operation" then
		member = nil
	end
	return member
end

return Indexer
