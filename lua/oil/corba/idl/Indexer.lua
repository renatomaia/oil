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
-- Title  : IDL Interface Indexer                                             --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- indexer:Facet
-- 	[interface:table] interfaceof(name:string)
-- 	member:table valueof(interface:table, name:string)
-- 
-- interfaces:Receptacle
-- 	[interface:table] lookup_id(repid:string)
-- 	[interface:table] lookup(name:string)
--------------------------------------------------------------------------------

local ipairs = ipairs

local oo     = require "oil.oo"
local assert = require "oil.assert"
local idl    = require "oil.corba.idl"                                          --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.idl.Indexer", oo.class)

context = false

--------------------------------------------------------------------------------
-- Internal Functions ----------------------------------------------------------

function findmember(self, interface, name)
	for interface in interface:hierarchy() do
		local member = interface.members[name]
		if member then return member, interface end
	end
end

patterns = { "^_([gs]et)_(.+)$" }

builders = {}
function builders:get(interface, attribute, opname)
	return idl.operation{
		name = opname,
		result = attribute.type,
		attribute = attribute,
		attribop = "get",
	}
end
function builders:set(interface, attribute, opname)
	return idl.operation{
		name = opname,
		parameters = { {type = attribute.type, name = "value"} },
		attribute = attribute,
		attribop = "set",
	}
end

--------------------------------------------------------------------------------
-- Interface Operations --------------------------------------------------------

function interfaceof(self, name)
	local interfaces = self.context.interfaces
	return interfaces:lookup_id(name) or
	       interfaces:lookup(name) or
	       assert.exception{ "INTERNAL", minor_code_value = 0,
	       	message = "unknown interface repository ID",
	       	reason = "interface",
	       	repID = name,
	       }
end

function valueof(self, interface, name)
	local member = self:findmember(interface, name)
	if not member then
		local action
		for _, pattern in ipairs(self.patterns) do
			action, member = name:match(pattern)
			if action then
				member = self:findmember(interface, member)
				if member then
					member = self.builders[action](self, interface, member, name, action)
					interface.members[name] = member
				end
			end
		end
	end
	return member
end
