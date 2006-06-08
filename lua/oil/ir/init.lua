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
-- Title  : Interface Repository (IR) object manager                          --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   new(ifaces) Creates new interface repository with interface map 'ifaces' --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local type         = type
local pairs        = pairs
local ipairs       = ipairs
local setmetatable = setmetatable
local require      = require
local getmetatable = getmetatable
local rawget       = rawget
local pack         = pack

local string = require "string"
local table  = require "table"

module "oil.ir"                                                                 --[[VERBOSE]] local verbose = require "oil.verbose"

local OrderedSet = require "loop.collection.OrderedSet"
local oo         = require "oil.oo"
local assert     = require "oil.assert"
local idl        = require "oil.idl"
local proxy      = require "oil.proxy"
local manager    = require "oil.manager"
local iridl      = require "oil.ir.idl"

local Empty = {}
local ObjectManager = manager.ObjectManager

--------------------------------------------------------------------------------
-- Classes ---------------------------------------------------------------------

local IRObject                = oo.class()
local Contained               = oo.class({}, IRObject)
local Container               = oo.class({}, IRObject)
local IDLType                 = oo.class({}, IRObject)

local PrimitiveDef            = oo.class({}, IDLType)
local ArrayDef                = oo.class({}, IDLType)
local SequenceDef             = oo.class({}, IDLType)
local StringDef               = oo.class({}, IDLType)
--local WstringDef              = oo.class({}, IDLType)
--local FixedDef                = oo.class({}, IDLType)

local AttributeDef            = oo.class({}, Contained)
local OperationDef            = oo.class({}, Contained)
--local ValueMemberDef          = oo.class({}, Contained)
--local ConstantDef             = oo.class({}, Contained)
local TypedefDef              = oo.class({}, Contained, IDLType)

local StructDef               = oo.class({}, TypedefDef , Container)
local UnionDef                = oo.class({}, TypedefDef , Container)
local EnumDef                 = oo.class({}, TypedefDef)
local AliasDef                = oo.class({}, TypedefDef)
--local NativeDef               = oo.class({}, TypedefDef)
--local ValueBoxDef             = oo.class({}, TypedefDef)

local Repository              = oo.class({}, ObjectManager, Container)
local ModuleDef               = oo.class({}, Contained, Container)
local ExceptionDef            = oo.class({}, Contained, Container)
local InterfaceDef            = oo.class({}, IDLType, Contained, Container)
--local ValueDef                = oo.class({}, Container, Contained, IDLType)

--local AbstractInterfaceDef    = oo.class({}, InterfaceDef)
--local LocalInterfaceDef       = oo.class({}, InterfaceDef)

--local ExtAttributeDef         = oo.class({}, AttributeDef)
--local ExtValueDef             = oo.class({}, ValueDef)
--local ExtInterfaceDef         = oo.class({}, InterfaceDef, InterfaceAttrExtension)
--local ExtAbstractInterfaceDef = oo.class({}, AbstractInterfaceDef, InterfaceAttrExtension)
--local ExtLocalInterfaceDef    = oo.class({}, LocalInterfaceDef, InterfaceAttrExtension)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--
-- Implementation
--
local function construct(obj, class, history)
	for _, super in oo.supers(class) do
		construct(obj, super, history)
	end
	if not history[class] then
		history[class] = true
		local constructor = rawget(class, "constructor")
		if constructor then constructor(obj) end
	end
	return obj
end
function IRObject:__init(def)
	return construct(oo.rawnew(self, def), self, {})
end

--
-- Operations
--
function IRObject:destroy()
	-- TODO:[maia] raise proper exception!
end

--------------------------------------------------------------------------------

--
-- Implementation
--
local function createrepid(name, version)                                       --[[VERBOSE]] verbose.ir_classes{"creating new repository ID from ", name, " ", version}
	return string.format("IDL:%s:%s",
	                     string.sub(string.gsub(name, "::", "/"), 2),
	                     version)
end

function Contained:constructor()
	local repository = self.containing_repository
	local defined_in = self.defined_in                                            --[[VERBOSE]] verbose.ir_classes({"constructing contained object ", self.name, " inside ", defined_in and defined_in.name, " (", self.repID, ")"}, true)
	
	if not defined_in then                                                        --[[VERBOSE]] verbose.ir_classes "contained object defines no container, repository containment assumed"
		self.defined_in = repository
		defined_in = repository
	end
	if not self.version then self.version = "1.0" end

	assert.type(repository, "table", "repository object")
	assert.type(defined_in, "table", "container object")
	assert.type(self.name, "string", "contained object name")                     --[[VERBOSE]] verbose.ir_classes({"attempt to construct parent object ", defined_in.name}, true)
	
	repository:newobject(defined_in)                                              --[[VERBOSE]] verbose.ir_classes()

	if not oo.instanceof(defined_in, Container) then
		assert.ilegal(defined_in, "container", "BAD_PARAM")
	elseif defined_in.containing_repository ~= repository then
		assert.ilegal(defined_in,
		              "container, repository does not match",
		              "BAD_PARAM")
	end

	if self.repID then self:_set_id(self.repID) end

	return self:move(self.defined_in, self.name, self.version)                    --[[VERBOSE]] , verbose.ir_classes()
end

function Contained:updatename()
	self.absolute_name = self.defined_in.absolute_name.."::"..self.name           --[[VERBOSE]] verbose.ir_classes({"updating contained object's absolute name to ", self.absolute_name}, true)
	if not self.repID then
		self:_set_id(createrepid(self.absolute_name, self.version))
	end
	if self.definitions and oo.instanceof(self, Container) then                   --[[VERBOSE]] verbose.ir_classes("updating members absolute names", true)
		for name, member in pairs(self.definitions) do
			if type(name) == "string" and oo.instanceof(member, Contained) then
				member:updatename()
			end
		end                                                                         --[[VERBOSE]] verbose.ir_classes()
	end                                                                           --[[VERBOSE]] verbose.ir_classes()
end

--
-- Attributes
--
function Contained:_set_id(id)                                                  --[[VERBOSE]] verbose.ir_classes{"setting contained object repID to ", id}
	local ifaces = self.containing_repository.ifaces
	if id ~= self.repID then
		if ifaces[id] then
			assert.ilegal(id, "repository ID, already exists", "BAD_PARAM", 2)
		end
		if self.repID then ifaces[self.repID] = nil end
		self.repID = id
	end
	self.id = id
	ifaces[id] = self
end

function Contained:_set_name(name)                                              --[[VERBOSE]] verbose.ir_classes({"setting contained object name to ", name}, true)
	local definitions = self.defined_in.definitions
	if name ~= self.name then
		if definitions[name] then
			assert.ilegal(name, "contained name, name clash", "BAD_PARAM", 1)
		end
		definitions[self.name] = nil
		self.name = name
	end
	definitions[name] = self
	self:updatename()                                                             --[[VERBOSE]] verbose.ir_classes()
end

--
-- Operations
--
local ContainedDescription = iridl.Contained.definitions.Description
function Contained:describe()                                                   --[[VERBOSE]] verbose.ir_classes{"describing contained object ", self.name}
	local description = self:get_description()
	description.name       = self.name
	description.id         = self.repID
	description.defined_in = self.defined_in.repID
	description.version    = self.version
	return setmetatable({
		kind = self.def_kind,
		value = description,
	}, ContainedDescription)
end

--function Contained:within() -- TODO:[maia] This op is described in specs but
--end                         --             is not listed in IR IDL!

function Contained:move(new_container, new_name, new_version)                   --[[VERBOSE]] verbose.ir_classes({"moving contained object into container ", new_container.name}, true)
	if new_container.containing_repository ~= self.containing_repository then
		assert.ilegal(new_container, "container", "BAD_PARAM", 4)
	end
	local oldcontained = new_container.definitions[new_name]
	if oldcontained and oldcontained ~= self then
		assert.ilegal(new_name, "contained name, already exists", "BAD_PARAM", 3)
	end
	if self.defined_in then
		self.defined_in.definitions[self.name] = nil                                --[[VERBOSE]] verbose.ir_classes{"contained object removed from old container ", self.defined_in.name}
	end
	self.defined_in = new_container
	self.version = new_version
	self:_set_name(new_name)                                                      --[[VERBOSE]] verbose.ir_classes()
end

--------------------------------------------------------------------------------

--
-- Implementation
--
function Container:constructor()                                                --[[VERBOSE]] verbose.ir_classes("constructing container object", true)
	if self.definitions then
		local repository = self.containing_repository
		for field, member in pairs(self.definitions) do
			if type(field) == "string" and not string.find(field, "^_") then          --[[VERBOSE]] verbose.ir_classes({"attempt to construct member object ", type(member) == "table" and member.name or member}, true)
				repository:newobject(member)                                            --[[VERBOSE]] verbose.ir_classes()
			end
		end
	else
		self.definitions = {}
	end                                                                           --[[VERBOSE]] verbose.ir_classes()
end

--
-- Read interface
--

function Container:lookup(search_name)                                          --[[VERBOSE]] verbose.ir_classes({ "searching for name ", search_name }, true)
	local scope
	if string.find(search_name, "^::") then
		scope = self.containing_repository
	else
		scope = self
		search_name = "::"..search_name
	end
	for nextscope in string.gmatch(search_name, "::([%w][_%w]*)") do               --[[VERBOSE]] verbose.ir_classes{"looking name ", nextscope, " in scope ", scope and scope.name} if not scope then verbose.ir_classes "scope not found!" elseif not scope.definitions then verbose.ir_classes "invalid scope!" end
		if not scope or not scope.definitions then return nil end
		scope = scope.definitions[nextscope]
	end
	return scope                                                                  --[[VERBOSE]] , verbose.ir_classes()
end

function Container:contents(limit_type, exclude_inherited, max_returned_objs)   --[[VERBOSE]] verbose.ir_classes({"returing up to ", max_returned_objs, " contents of kind ", limit_type}, true)
	-- TODO:[maia] finish implementation
	if not contents then contents = {} end
	for name, member in pairs(self.definitions)	do
		if
			type(name) == "string" and
			(limit_type == "dk_all" or member.def_kind == limit_type)
		then
			if max_returned_objs == 0 then break end                                  --[[VERBOSE]] verbose.ir_classes{"including member ", member.name}
			table.insert(contents, member)
			max_returned_objs = max_returned_objs - 1
		end
	end
	return contents, max_returned_objs                                            --[[VERBOSE]] , verbose.ir_classes()
end

function Container:lookup_name(search_name, levels_to_search,
                               limit_type, exclude_inherited)
	-- TODO:[maia] finish implementation
	if not results then results = {} end
	for name, member in pairs(self.definitions)	do
		if
			type(name) == "string" and
			(limit_type == "dk_all" or member.def_kind == limit_type)
		then
			table.insert(results, member)
		end
	end
	return results
end

local ContainerDescription = iridl.Container.definitions.Description
function Container:describe_contents(limit_type, exclude_inherited,
                                     max_returned_objs)                         --[[VERBOSE]] verbose.ir_classes("describing contents", true)
	local contents = self:contents(limit_type,
	                               exclude_inherited,
	                               max_returned_objs)
	for index, content in ipairs(contents) do
		contents[index] = setmetatable({
			contained_object = content,
			kind = content.def_kind,
			value = content:describe(),
		}, ContainerDescription)
	end
	
	return contents                                                               --[[VERBOSE]] , verbose.ir_classes()
end

--
-- Write interface
--

function Container:create_module(id, name, version)
	return ModuleDef{
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
	}
end

--function Container:create_constant(id, name, version, type, value)
--end

function Container:create_struct(id, name, version, members)
	return StructDef{
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
		
		fields = members,
	}
end

function Container:create_union(id, name, version, discriminator_type, members)
	return UnionDef{
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
		
		discriminator_type_def = discriminator_type,
		switch = discriminator_type.type,
		members = members,
	}
end

function Container:create_enum(id, name, version, members)
	return EnumDef{
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
		
		enumvalues = members,
	}
end

function Container:create_alias(id, name, version, original_type)
	return AliasDef{
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
		
		original_type_def = original_type,
		type = original_type.type
	}
end

function Container:create_interface(id, name, version, base_interfaces)
	return InterfaceDef{
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,

		base_interfaces = base_interfaces,
	}
end

--function Container:create_value(id, name, version,
--                                is_custom,
--                                is_abstract,
--																base_value,
--																is_truncatable,
--																abstract_base_values,
--																supported_interfaces,
--																initializers)
--end
--
--function Container:create_value_box(id, name, version, original_type_def)
--end

function Container:create_exception(id, name, version, members)
	return ExceptionDef{
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
		
		members = members,
	}
end

--function Container:create_native(id, name, version)
--end
--
--function Container:create_abstract_interface(id, name, version, base_interfaces)
--end
--
--function Container:create_local_interface(id, name, version, base_interfaces)
--end
--
--function Container:create_ext_value(id, name, version,
--                                    is_custom,
--                                    is_abstract,
--                                    base_value,
--                                    is_truncatable,
--                                    abstract_base_values,
--                                    supported_interfaces,
--                                    initializers)
--end

--------------------------------------------------------------------------------

function IDLType:constructor()                                                  --[[VERBOSE]] verbose.ir_classes "constructing IDL type object"
	if not self.type then self.type = self end
end

--------------------------------------------------------------------------------

local ObjectRef = oo.class({}, PrimitiveDef)
ObjectRef._type = "Object"
ObjectRef.kind = "pk_objref"
ObjectRef.repID = "IDL:omg.org/CORBA/Object:1.0"
ObjectRef.name = "Object"

function ObjectRef:constructor()
	if self.repID ~= ObjectRef.repID then
		assert.raise{ "INTERNAL", minor_code_value = 0,
			reason = "IRObject",
			message = "ilegal Object type, use interface definition instead",
		}
	end
end

--------------------------------------------------------------------------------

PrimitiveDef.def_kind = "dk_Primitive"

PrimitiveDef(idl.null    ).kind = "pk_null"
PrimitiveDef(idl.void    ).kind = "pk_void"
PrimitiveDef(idl.short   ).kind = "pk_short"
PrimitiveDef(idl.long    ).kind = "pk_long"
PrimitiveDef(idl.ushort  ).kind = "pk_ushort"
PrimitiveDef(idl.ulong   ).kind = "pk_ulong"
PrimitiveDef(idl.float   ).kind = "pk_float"
PrimitiveDef(idl.double  ).kind = "pk_double"
PrimitiveDef(idl.boolean ).kind = "pk_boolean"
PrimitiveDef(idl.char    ).kind = "pk_char"
PrimitiveDef(idl.octet   ).kind = "pk_octet"
PrimitiveDef(idl.any     ).kind = "pk_any"
PrimitiveDef(idl.TypeCode).kind = "pk_TypeCode"
PrimitiveDef(idl.string  ).kind = "pk_string"
--PrimitiveDef(    objref  ).kind = "pk_objref"

--------------------------------------------------------------------------------

ArrayDef.def_kind = "dk_Array"
ArrayDef._type = "array"

function ArrayDef:constructor()                                                 --[[VERBOSE]] verbose.ir_classes("constructing ArrayDef object", true)
	if not self.element_type_def then                                             --[[VERBOSE]] verbose.ir_classes("attempt to construct element type object", true)
		self.containing_repository:newobject(self.elementtype)                      --[[VERBOSE]] verbose.ir_classes()
		self:_set_element_type_def(self.elementtype)                                --[[VERBOSE]] verbose.ir_classes()
	end
end

function ArrayDef:_get_element_type() return self.elementtype end

function ArrayDef:_set_element_type_def(type_def)                               --[[VERBOSE]] verbose.ir_classes "setting sequence/array element type"
	self.element_type_def = type_def
	self.elementtype = type_def.type
end

--------------------------------------------------------------------------------

SequenceDef.def_kind = "dk_Sequence"
SequenceDef._type = "sequence"

function SequenceDef:constructor()                                              --[[VERBOSE]] verbose.ir_classes("constructing SequenceDef object", true)
	if not self.element_type_def then                                             --[[VERBOSE]] verbose.ir_classes("attempt to construct element type object", true)
		self.containing_repository:newobject(self.elementtype)                     --[[VERBOSE]] verbose.ir_classes()
		self:_set_element_type_def(self.elementtype)
	end                                                                           --[[VERBOSE]] verbose.ir_classes()
end

SequenceDef._get_element_type = ArrayDef._get_element_type
SequenceDef._set_element_type_def = ArrayDef._set_element_type_def
function SequenceDef:_set_bound(value) self.maxlength = value end
function SequenceDef:_get_bound() return self.maxlength end

--------------------------------------------------------------------------------

StringDef.def_kind = "dk_String"
StringDef._type = "string"
StringDef.maxlength = 0
StringDef._set_bound = SequenceDef._set_bound
StringDef._get_bound = SequenceDef._get_bound

--------------------------------------------------------------------------------

AttributeDef.def_kind = "dk_Attribute"
AttributeDef._type = "attribute"

function AttributeDef:get_description()                                         --[[VERBOSE]] verbose.ir_classes "creating attribute description"
	return setmetatable({
		type = self.type,
		mode = self.mode,
	}, iridl.AttributeDescription)
end

function AttributeDef:constructor()                                             --[[VERBOSE]] verbose.ir_classes("constructing AttributeDef object", true)
	if not self.mode then
		self.mode = (self.readonly and "ATTR_READONLY" or "ATTR_NORMAL")
	end
	if not self.type_def then                                                     --[[VERBOSE]] verbose.ir_classes("attempt to construct element type object", true)
		self.containing_repository:newobject(self.type)                             --[[VERBOSE]] verbose.ir_classes()
		self:_set_type_def(self.type)
	end
	
	self.defined_in.members[self.name] = self	                                    --[[VERBOSE]] verbose.ir_classes()
end

function AttributeDef:_set_mode(value)                                          --[[VERBOSE]] verbose.ir_classes "setting attribute mode"
	self.mode = value
	self.readonly = (value == "ATTR_READONLY")
end

function AttributeDef:_set_type_def(type_def)                                   --[[VERBOSE]] verbose.ir_classes "setting attribute type"
	self.type_def = type_def
	self.type = type_def.type
end

--------------------------------------------------------------------------------

OperationDef.def_kind = "dk_Operation"
OperationDef._type = "operation"
OperationDef.contexts = Empty
OperationDef.parameters = Empty
OperationDef.exceptions = Empty
OperationDef.result = idl.void

function OperationDef:get_description()                                         --[[VERBOSE]] verbose.ir_classes "creating operation description"
	local exceptions = {}
	for index, except in ipairs(self.exceptions) do
		exceptions[index] = except:describe().value
	end
	return setmetatable({
		result     = self.result,
		mode       = self.mode,
		contexts   = self.contexts,
		parameters = self.parameters,
		exceptions = exceptions,
	}, iridl.OperationDescription)
end

function OperationDef:constructor()                                             --[[VERBOSE]] verbose.ir_classes("constructing OperationDef object", true)
	if not self.mode then
		self.mode = (self.oneway and "OP_ONEWAY" or "OP_NORMAL")
	end
	local repository = self.containing_repository
	for _, param in ipairs(self.parameters) do
		if not param.type_def then                                                  --[[VERBOSE]] verbose.ir_classes("attempt to construct parameter ", _, " type object", true)
			repository:newobject(param.type)                                          --[[VERBOSE]] verbose.ir_classes()
			param.type_def = param.type
		end
	end
	for _, except in ipairs(self.exceptions) do                                   --[[VERBOSE]] verbose.ir_classes("attempt to construct raised exception ", except.name, " type object", true)
		repository:newobject(except)                                                --[[VERBOSE]] verbose.ir_classes()
	end
	if not self.result_def then                                                   --[[VERBOSE]] verbose.ir_classes("attempt to construct result type object", true)
		repository:newobject(self.result)                                           --[[VERBOSE]] verbose.ir_classes()
		self:_set_result_def(self.result)
	end
	self:_set_params(self.parameters)
	self:_set_exceptions(self.exceptions)

	self.defined_in.members[self.name] = self	                                    --[[VERBOSE]] verbose.ir_classes()
end

function OperationDef:_set_mode(value)                                          --[[VERBOSE]] verbose.ir_classes "setting operation mode"
	self.mode = value
	self.oneway = (value == "OP_ONEWAY")
end

function OperationDef:_set_result_def(type_def)                                 --[[VERBOSE]] verbose.ir_classes "setting operation result type"
	self.result_def = type_def
	self.result = type_def.type
end

function OperationDef:_get_params() return self.parameters end
function OperationDef:_set_params(parameters)                                   --[[VERBOSE]] verbose.ir_classes "setting operation parameters"
	local inputs = {}
	local outputs = {}
	if self.result and self.result ~= idl.void then
		table.insert(outputs, self.result)
	end
	for _, param in ipairs(parameters) do
		param.type = param.type_def.type
		if param.mode == nil or param.mode == "PARAM_IN" then
			table.insert(inputs, param.type)
		elseif param.mode == "PARAM_OUT" then
			table.insert(outputs, param.type)
		elseif param.mode == "PARAM_INOUT" then
			table.insert(inputs, param.type)
			table.insert(outputs, param.type)
		else
			assert.ilegal(param.mode, "operation parameter mode")
		end
	end
	self.parameters = parameters
	self.inputs = inputs
	self.outputs = outputs
end

function OperationDef:_set_exceptions(excepts)                                  --[[VERBOSE]] verbose.ir_classes "setting operation raised exceptions"
	for _, except in ipairs(excepts) do
		excepts[except.repID] = except
	end
	self.exceptions = excepts
end

--------------------------------------------------------------------------------

TypedefDef.def_kind = "dk_Typedef"
TypedefDef._type = "typedef"

function TypedefDef:get_description()                                           --[[VERBOSE]] verbose.ir_classes "creating type definition description"
	return setmetatable({ type = self.type }, iridl.TypeDescription)
end

--------------------------------------------------------------------------------

StructDef.def_kind = "dk_Struct"
StructDef._type = "struct"

function StructDef:constructor()                                                --[[VERBOSE]] verbose.ir_classes("constructing StructDef object", true)
	local repository = self.containing_repository
	for _, field in ipairs(self.fields) do
		if not field.type_def then                                                  --[[VERBOSE]] verbose.ir_classes("attempt to construct struct field type object", true)
			repository:newobject(field.type)                                          --[[VERBOSE]] verbose.ir_classes()
			field.type_def = field.type
		end
	end
	self:_set_members(self.fields)                                                --[[VERBOSE]] verbose.ir_classes()
end

StructDef._set_type_def = AttributeDef._set_type_def

function StructDef:_get_members() return self.fields end
function StructDef:_set_members(members)
	for _, field in ipairs(members) do
		field.type = field.type_def.type
	end
	self.fields = members
end

--------------------------------------------------------------------------------

UnionDef.def_kind = "dk_Union"
UnionDef._type = "union"
UnionDef.default = -1

function UnionDef:constructor()                                                 --[[VERBOSE]] verbose.ir_classes("constructing UnionDef object", true)
	local repository = self.containing_repository
	if not self.discriminator_type_def then                                       --[[VERBOSE]] verbose.ir_classes("attempt to construct switch type object", true)
		repository:newobject(self.switch)                                           --[[VERBOSE]] verbose.ir_classes()
		self:_set_discriminator_type_def(self.switch)
	end
	if not self.members then
		local members = {}
		for index, option in ipairs(self.options) do                                --[[VERBOSE]] verbose.ir_classes({"attempt to construct option ", option.name, " type object"}, true)
			repository:newobject(option.type)                                         --[[VERBOSE]] verbose.ir_classes()
			members[index] = {
				name = option.name,
				label = setmetatable({option.label}, self.switch),
				type_def = option.type,
				type = option.type.type,
			}
		end
		self.members = members
	elseif not self.options then
		self:_set_members(self.members)
	end
end

function UnionDef:_get_discriminator_type() return self.switch end

function UnionDef:_set_discriminator_type_def(type_def)                         --[[VERBOSE]] verbose.ir_classes "setting union discriminator type"
	self.discriminator_type_def = type_def
	self.switch = type_def.type
end

function UnionDef:_set_members(members)                                         --[[VERBOSE]] verbose.ir_classes "setting union members"
	local options = {}
	local selector = {}
	local selection = {}
	for index, member in ipairs(members) do
		local option = {
			label = member.label[1],
			name = member.name,
			type = member.type_def.type,
		}
		options[index] = option
		selector[option.name] = option.label
		selection[option.label] = option
	end
	self.options = options
	self.selector = selector
	self.selection = selection
end

--------------------------------------------------------------------------------

EnumDef.def_kind = "dk_Enum"
EnumDef._type = "enum"

function EnumDef:constructor()                                                  --[[VERBOSE]] verbose.ir_classes("constructing EnumDef object", true)
	self:_set_members(self.enumvalues)                                            --[[VERBOSE]] verbose.ir_classes()
end

function EnumDef:_get_members() return self.enumvalues end
function EnumDef:_set_members(members)
	local labelvalue = {}
	for index, label in ipairs(members) do
		labelvalue[label] = index - 1
	end
	self.enumvalues = members
	self.labelvalue = labelvalue
end

--------------------------------------------------------------------------------

AliasDef.def_kind = "dk_Alias"
AliasDef._type = "typedef"

function AliasDef:_set_original_type_def(type_def)
	self.original_type_def = type_def
	self.type = type_def.type
end

--------------------------------------------------------------------------------

Repository.repID = ""
Repository.absolute_name = ""

Repository.primitive = {
	pk_null     = idl.null,
	pk_void     = idl.void,
	pk_short    = idl.short,
	pk_long     = idl.long,
	pk_ushort   = idl.ushort,
	pk_ulong    = idl.ulong,
	pk_float    = idl.float,
	pk_double   = idl.double,
	pk_boolean  = idl.boolean,
	pk_char     = idl.char,
	pk_octet    = idl.octet,
	pk_any      = idl.any,
	pk_TypeCode = idl.TypeCode,
	pk_string   = idl.string,
	pk_objref   = ObjectRef(),
}

local Classes = {
	struct     = StructDef,
	union      = UnionDef,
	enum       = EnumDef,
	sequence   = SequenceDef,
	array      = ArrayDef,
	string     = StringDef,
	typedef    = AliasDef,
	except     = ExceptionDef,
	attribute  = AttributeDef,
	operation  = OperationDef,
	module     = ModuleDef,
	interface  = InterfaceDef,
	Object     = ObjectRef,
}
function Repository:newobject(object)
	if getmetatable(object) == nil then                                           --[[VERBOSE]] verbose.ir_classes "creating new IR object from IDL definition"
		object.containing_repository = self
		return Classes[object._type](object)
	elseif
		object._is_a and
		object:_is_a("IDL:omg.org/CORBA/InterfaceDef:1.0")
	then
		return proxy.interface(object)                                              --[[VERBOSE]] else verbose.ir_classes "object already is an IR object"
	end
end

function Repository:__init(object)                                              --[[VERBOSE]] verbose.ir_classes("creating new repository", true)
	ObjectManager.__init(self, object)
	object.containing_repository = object
	return IRObject.__init(self, object)                                          --[[VERBOSE]] , verbose.ir_classes()
end

function Repository:constructor()                                               --[[VERBOSE]] verbose.ir_classes("constructing Repository object", true)
	for repID, iface in pairs(self.ifaces) do
		if type(iface) == "table" and iface._type == "interface" then
			self:newobject(iface)
		end
	end                                                                           --[[VERBOSE]] verbose.ir_classes()
end

function Repository:putiface(def)
	assert.type(def, "idlinterface", "interface")
	local repID = def.repID
	assert.type(repID, "string", "interface repository ID")

	local interface = rawget(self.ifaces, repID)
	if interface ~= def then
		if interface then                                                           --[[VERBOSE]] verbose.ir_manager{"replace definition of ", repID}
			---- redefine interface members
			--interface:update(def)
			--
			---- redefine interface class
			--proxyclass = rawget(self.classes, repID)
			--if proxyclass then                                                        --[[VERBOSE]] verbose.ir_manager{"replace proxy class of ", repID}
			--	-- TODO: reset proxy class members, so new operation stubs will be created
			--	local handlers = proxyclass._handlers
			--	table.clear(proxyclass)
			--	proxyclass._iface = interface
			--	proxyclass._manager = self
			--	proxyclass._handlers = handlers
			--	proxyclass.__index = proxy.Object.__index
			--	proxyclass.__newindex = proxy.Object.__newindex
			--end
		else                                                                        --[[VERBOSE]] verbose.ir_manager({"register definition of ", repID}, true)
			if getmetatable(def) then                                                 --[[VERBOSE]] verbose.ir_manager "remote or customized interface description"
				interface = def
				self.ifaces[repID] = interface
			else                                                                      --[[VERBOSE]] verbose.ir_manager "creating InterfaceDef from description"
				def.containing_repository = self
				if not def.defined_in then def.defined_in = self end
				interface = InterfaceDef(def)
			end                                                                       --[[VERBOSE]] verbose.ir_manager()
		end
	end
	return interface
end

--
-- Read interface
--

function Repository:lookup(search_name)
	local iface = Container.lookup(self, search_name)
	if not iface and self.ir then                                                 --[[VERBOSE]] verbose.ir_classes("looking up name on remote IR", true)
		iface = self.ir:lookup(search_name)                                         --[[VERBOSE]] verbose.ir_classes()
		if iface then
			iface = self:newobject(
				iface:_narrow("IDL:omg.org/CORBA/InterfaceDef:1.0")
			)
		end
	end
	return iface
end

function Repository:lookup_id(search_id)                                        --[[VERBOSE]] verbose.ir_classes({"looking up of object with ir ", search_id}, true)
	return self.ifaces[search_id]                                                 --[[VERBOSE]] , verbose.ir_classes()
end

--function Repository:get_canonical_typecode(tc)
--end

function Repository:get_primitive(kind)                                         --[[VERBOSE]] verbose.ir_classes{"getting primitive ", kind}
	return self.primitive[kind]
end

--
-- Write interface
--
--
--function Repository:create_string(bound)
--end
--
--function Repository:create_wstring(bound)
--end

function Repository:create_sequence(bound, element_type)
	return SequenceDef{
		containing_repository = self,
		
		element_type_def = element_type,
		elementtype = element_type.type,
		maxlength = bound,
	}
end

function Repository:create_array(length, element_type)
	return ArrayDef{
		containing_repository = self,
		
		element_type_def = element_type,
		elementtype = element_type.type,
		length = length,
	}
end

--function Repository:create_fixed(digits, scale)
--end

--------------------------------------------------------------------------------

--function ExtAttributeDef:describe_attribute()
--end

--------------------------------------------------------------------------------

ModuleDef.def_kind = "dk_Module"
ModuleDef._type = "module"

function ModuleDef:get_description()                                            --[[VERBOSE]] verbose.ir_classes "creating module description"
	return setmetatable({}, iridl.ModuleDescription)
end

--------------------------------------------------------------------------------

ExceptionDef.def_kind = "dk_Exception"
ExceptionDef._type = "except"

function ExceptionDef:get_description()                                         --[[VERBOSE]] verbose.ir_classes "creating exception description"
	return setmetatable({ type = self }, iridl.ExceptionDescription)
end

function ExceptionDef:constructor()
	self.type = self
	local repository = self.containing_repository
	for _, member in ipairs(self.members) do
		if not member.type_def then                                                 --[[VERBOSE]] verbose.ir_classes("attempt to construct exception member type object", true)
			repository:newobject(member.type)                                         --[[VERBOSE]] verbose.ir_classes()
			member.type_def = member.type
		end
		member.type = member.type_def.type
	end
end

--------------------------------------------------------------------------------

InterfaceDef.def_kind = "dk_Interface"
InterfaceDef._type = "interface"
InterfaceDef.base_interfaces = { {
	repID = "IDL:omg.org/CORBA/Object:1.0",
	members = Empty,
} }

function InterfaceDef:get_description()                                         --[[VERBOSE]] verbose.ir_classes "creating interface description"
	local bases = {}
	for index, base in ipairs(self.base_interfaces) do
		bases[index] = base.repID
	end
	return setmetatable({ base_interfaces = bases }, iridl.InterfaceDescription)
end

function InterfaceDef:constructor()                                             --[[VERBOSE]] verbose.ir_classes({"constructing InterfaceDef type object"}, true)
	self.members = idl.InterfaceMemberList(self.members, self)
	local repository = self.containing_repository
	for _, member in pairs(self.members) do
		if not member.attribute then                                                --[[VERBOSE]] verbose.ir_classes({"attempt to construct interface member ", member.name}, true)
			repository:newobject(member)                                              --[[VERBOSE]] verbose.ir_classes()
		end
	end
	for _, base in ipairs(self.base_interfaces) do                                --[[VERBOSE]] verbose.ir_classes({"attempt to construct base interface ", base.name, " type object"}, true)
		repository:newobject(base)                                                  --[[VERBOSE]] verbose.ir_classes()
	end                                                                           --[[VERBOSE]] verbose.ir_classes()
end

--
-- Read interface
--

function InterfaceDef:is_a(interface_id)
	if interface_id == self.repID then return true end
	for _, base in ipairs(self.base_interfaces) do
		if base:is_a(interface_id) then return true end
	end
	return false
end

local FullIfaceDescription = iridl.InterfaceDef.definitions.FullInterfaceDescription
function InterfaceDef:describe_interface()                                      --[[VERBOSE]] verbose.ir_classes("describing interface ", true)
	local operations = {}
	local attributes = {}
	local base_interfaces = {}
	for _, base in ipairs(self.base_interfaces) do                                --[[VERBOSE]] verbose.ir_classes{"adding base interface ", base.absolute_name}
		table.insert(base_interfaces, base.repID)
	end
	local queue = OrderedSet{ self }
	local iface = OrderedSet.firstkey
	while queue[iface] do iface = queue[iface]                                    --[[VERBOSE]] verbose.ir_classes({"adding members from interface ", iface.absolute_name}, true)
		for _, member in pairs(iface.members) do
			if member._type == "attribute" then                                       --[[VERBOSE]] verbose.ir_classes({"adding attribute ", member.name}, true)
				table.insert(attributes, member:describe().value)                       --[[VERBOSE]] verbose.ir_classes()
			elseif member._type == "operation" and not member.attribute then          --[[VERBOSE]] verbose.ir_classes({"adding operation ", member.name}, true)
				table.insert(operations, member:describe().value)                       --[[VERBOSE]] verbose.ir_classes()
			end
		end                                                                         --[[VERBOSE]] verbose.ir_classes()
		for _, base in ipairs(iface.base_interfaces) do
			if not queue:contains(base) then queue:enqueue(base) end
		end
	end                                                                           --[[VERBOSE]] verbose.ir_classes()
	return setmetatable({
		name = self.name,
		id = self.id,
		defined_in = self.defined_in.repID,
		version = self.version,
		base_interfaces = base_interfaces,
		type = self,
		operations = operations,
		attributes = attributes,
	}, FullIfaceDescription)
end

--
-- Write interface
--

function InterfaceDef:_set_base_interfaces(bases)
	-- TODO:[maia] implement it. See section 10.5.24.2 of CORBA specs
end

function InterfaceDef:create_attribute(id, name, version, type, mode)
	return AttributeDef {
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
		
		type_def = type,
		type = type.type,
		readonly = (mode == "ATTR_READONLY"),
	}
end

function InterfaceDef:create_operation(id, name, version,
                                       result, mode, params,
                                       exceptions, contexts)
	return OperationDef {
		containing_repository = self.containing_repository,
		defined_in = self,
		
		repID = id,
		name = name,
		version = version,
		
		result_def = result,
		result = result.type,
		
		parameters = params,
		exceptions = exceptions,
		contexts = contexts,
		
		oneway = (mode == "OP_ONEWAY"),
	}
end

--------------------------------------------------------------------------------

--
-- Read interface
--
--
--function InterfaceAttrExtension:describe_ext_interface()
--end

--
-- Write interface
--
--
--function InterfaceAttrExtension:create_ext_attribute()
--end

--------------------------------------------------------------------------------

--
-- Read interface
--
--
--function ValueDef:is_a(id)
--end
--
--function ValueDef:describe_value()
--end

--
-- Write interface
--
--
--function ValueDef:create_value_member(id, name, version, type, access)
--end
--
--function ValueDef:create_attribute(id, name, version, type, mode)
--end
--
--function ValueDef:create_operation(id, name, version,
--                                   result, mode, params,
--                                   exceptions, contexts)
--end

--------------------------------------------------------------------------------

--
-- Read interface
--
--
--function ExtValueDef:describe_ext_value()
--end

--
-- Write interface
--
--
--function ExtValueDef:create_ext_attribute(id, name, version, type, mode,
--                                          get_exceptions, set_exceptions)
--end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function new(ifaces)                                                            --[[VERBOSE]] verbose.ir_classes({"instantiating new integrated IR with map ", ifaces}, true)
	return Repository{ ifaces = ifaces }, iridl.Repository                        --[[VERBOSE]] , verbose.ir_classes()
end
