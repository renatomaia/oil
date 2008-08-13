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
-- Title  : Server-Side Interface Indexer                                     --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- indexer:Facet
-- 	interface:table typeof(reference:table)
-- 	member:table, [islocal:function], [cached:boolean] valueof(interface:table, name:string)
--
--
--------------------------------------------------------------------------------

local rawget = rawget
local rawset = rawset

local oo      = require "oil.oo"
local Indexer = require "oil.corba.giop.Indexer"                                --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.giop.ServantOps"

oo.class(_M, Indexer)

--------------------------------------------------------------------------------

localops = {}

function localops:_non_existent()
	return false
end

function localops:_component()
	return nil
end

local curriface

function localops:_interface()
	return curriface
end

function localops:_is_a(repid)
	for base in curriface:hierarchy() do
		if base.repID == repid then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------

attribops = {}

local attribute
function attribops:get() return self[attribute] end
function attribops:set(value) self[attribute] = value end

--------------------------------------------------------------------------------

function valueof(self, interface, name)
	local member, value = Indexer.valueof(self, interface, name)
	if member and member._type == "operation" then
		value = self.localops[name]
		if value == nil then
			attribute = member.attribute and member.attribute.name
			value = self.attribops[member.attribop]
		else
			curriface = interface
		end
	else
		member, value = nil, nil
	end
	return member, value, true
end
