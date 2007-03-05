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
-- Release: 0.4 alpha                                                         --
-- Title  : IDL Definition Repository                                         --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- importer:Facet
-- 	type:table register(definition:table)
-- 	type:table remove(definition:table)
-- 	[type:table] lookup(name:string)
-- 	[type:table] lookup_id(repid:string)
-- 
-- types:Receptacle
-- 	type:table register(definition:table)
-- 	type:table remove(definition:table)
-- 	[type:table] lookup(name:string)
-- 	[type:table] lookup_id(repid:string)
-- 
-- remote:Recetacle
-- 	[type:table] lookup(name:string)
-- 	[type:table] lookup_id(repid:string)
--------------------------------------------------------------------------------

local error  = error
local ipairs = ipairs

local oo       = require "oil.oo"
local idl      = require "oil.corba.idl"
local iridl    = require "oil.corba.idl.ir"
local Registry = require "oil.corba.idl.Registry"                               --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.idl.Importer", oo.class)

resolve = Registry.resolve

function context(self, context)
	self.context = context
	context.types:register(iridl.InterfaceDef)
end

function lookup(self, search_name)
	local context = self.context
	local definition = context.types:lookup(search_name)
	if not definition then
		if context.remote then
			definition = context.remote:lookup(search_name)
			if definition then
				definition = self:register(definition)
			end
		end
	end
	return definition
end

function lookup_id(self, search_id)
	local context = self.context
	local definition = context.types:lookup_id(search_id)
	if not definition then
		if context.remoteir then
			definition = context.remoteir:lookup_id(search_id)
			if definition then
				definition = self:register(definition)
			end
		end
	end
	return definition
end

local IDLTypes = {
	dk_Primitive = true,
	dk_Array     = true,
	dk_Sequence  = true,
	dk_String    = true,
	dk_Typedef   = true,
	dk_Struct    = true,
	dk_Union     = true,
	dk_Enum      = true,
	dk_Alias     = true,
	dk_Exception = true,
}

function register(self, object, history)
	local result
	local types = self.context.types
	if object._get_def_kind then
		history = history or {}
		local kind = object:_get_def_kind()
		if IDLTypes[kind] then
			result = types:register(object:_get_type())
		elseif kind == "dk_Repository" then
			result = types
		elseif object:_is_a("IDL:omg.org/CORBA/Contained:1.0") then
			object = object:_narrow("IDL:omg.org/CORBA/Contained:1.0")
			local desc = object:describe().value
			result = history[desc.id] 
			if not result then
				desc.repID = desc.id
				desc.defined_in = nil
				if kind == "dk_Interface" then
					desc = types:register(idl.interface(desc))
					history[desc.repID] = desc
					object = object:_narrow("IDL:omg.org/CORBA/InterfaceDef:1.0")
					desc:move(
						self:register(object:_get_defined_in(), history),
						desc.name,
						desc.version
					)
					desc:_set_base_interfaces(object:_get_base_interfaces())
					local info = object:describe_interface()
					for _, attribute in ipairs(info.attributes) do
						attribute.repID = attribute.id
						attribute.defined_in = desc
						types:register(idl.attribute(attribute))
					end
					for _, operation in ipairs(info.operations) do
						operation.repID = operation.id
						operation.defined_in = desc
						for index, except in ipairs(operation.exceptions) do
							operation.exceptions[index] = except.type
						end
						types:register(idl.operation(operation))
					end
				elseif kind == "dk_Module" then
					desc = types:register(idl.module(desc))
					history[desc.repID] = desc
					object = object:_narrow("IDL:omg.org/CORBA/ModuleDef:1.0")
					for _, contained in ipairs(object:contents("dk_all", true)) do
						self:register(contained, history)
					end
				elseif kind == "dk_Attribute" or kind == "dk_Operation" then
					desc = self:register(object:_get_defined_in(), history).members[desc.name]
					history[desc.repID] = desc
				else
					error("unable to import "..kind:match("^dk_(.+)$"))
				end
				result = desc
			end
		else
			error("unable to import definition of type "..object:_interface():_get_id())
		end
	else
		result = types:register(object)
	end
	return result
end
