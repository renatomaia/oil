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
-- Title  : IDL Definition Registry                                           --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- interfaces:Facet
-- 	interface:table register(definition:table)
-- 	interface:table remove(definition:table)
-- 	[interface:table] lookup(name:string)
-- 	[interface:table] lookup_id(repid:string)
--------------------------------------------------------------------------------

local error        = error
local ipairs       = ipairs
local pairs        = pairs
local rawget       = rawget
local select       = select
local setmetatable = setmetatable
local type         = type
local unpack       = unpack

local string = require "string"
local table  = require "table"

local ObjectCache = require "loop.collection.ObjectCache"
local OrderedSet  = require "loop.collection.OrderedSet"

local oo        = require "oil.oo"
local assert    = require "oil.assert"
local idl       = require "oil.corba.idl"
local iridl     = require "oil.corba.idl.ir"                                    --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.idl.Registry"

--------------------------------------------------------------------------------
-- Internal classes ------------------------------------------------------------

  IRObject                = oo.class()
  Contained               = oo.class({}, IRObject)
  Container               = oo.class({}, IRObject)
  IDLType                 = oo.class({}, IRObject)
  
  PrimitiveDef            = oo.class({ __idltype = "IDL:omg.org/CORBA/PrimitiveDef:1.0"            }, IDLType)
  ArrayDef                = oo.class({ __idltype = "IDL:omg.org/CORBA/ArrayDef:1.0"                }, IDLType)
  SequenceDef             = oo.class({ __idltype = "IDL:omg.org/CORBA/SequenceDef:1.0"             }, IDLType)
  StringDef               = oo.class({ __idltype = "IDL:omg.org/CORBA/StringDef:1.0"               }, IDLType)
--WstringDef              = oo.class({ __idltype = "IDL:omg.org/CORBA/WstringDef:1.0"              }, IDLType)
--FixedDef                = oo.class({ __idltype = "IDL:omg.org/CORBA/FixedDef:1.0"                }, IDLType)
  
  AttributeDef            = oo.class({ __idltype = "IDL:omg.org/CORBA/AttributeDef:1.0"            }, Contained)
  OperationDef            = oo.class({ __idltype = "IDL:omg.org/CORBA/OperationDef:1.0"            }, Contained)
--ValueMemberDef          = oo.class({ __idltype = "IDL:omg.org/CORBA/ValueMemberDef:1.0"          }, Contained)
--ConstantDef             = oo.class({ __idltype = "IDL:omg.org/CORBA/ConstantDef:1.0"             }, Contained)
  TypedefDef              = oo.class({ __idltype = "IDL:omg.org/CORBA/TypedefDef:1.0"              }, Contained, IDLType)
  
  StructDef               = oo.class({ __idltype = "IDL:omg.org/CORBA/StructDef:1.0"               }, TypedefDef , Container)
  UnionDef                = oo.class({ __idltype = "IDL:omg.org/CORBA/UnionDef:1.0"                }, TypedefDef , Container)
  EnumDef                 = oo.class({ __idltype = "IDL:omg.org/CORBA/EnumDef:1.0"                 }, TypedefDef)
  AliasDef                = oo.class({ __idltype = "IDL:omg.org/CORBA/AliasDef:1.0"                }, TypedefDef)
--NativeDef               = oo.class({ __idltype = "IDL:omg.org/CORBA/NativeDef:1.0"               }, TypedefDef)
--ValueBoxDef             = oo.class({ __idltype = "IDL:omg.org/CORBA/ValueBoxDef:1.0"             }, TypedefDef)
  
  Repository              = oo.class({ __idltype = "IDL:omg.org/CORBA/Repository:1.0"              }, Container)
  ModuleDef               = oo.class({ __idltype = "IDL:omg.org/CORBA/ModuleDef:1.0"               }, Contained, Container)
  ExceptionDef            = oo.class({ __idltype = "IDL:omg.org/CORBA/ExceptionDef:1.0"            }, Contained, Container)
  InterfaceDef            = oo.class({ __idltype = "IDL:omg.org/CORBA/InterfaceDef:1.0"            }, IDLType, Contained, Container)
--ValueDef                = oo.class({ __idltype = "IDL:omg.org/CORBA/ValueDef:1.0"                }, Container, Contained, IDLType)
  
--AbstractInterfaceDef    = oo.class({ __idltype = "IDL:omg.org/CORBA/AbstractInterfaceDef:1.0"    }, InterfaceDef)
--LocalInterfaceDef       = oo.class({ __idltype = "IDL:omg.org/CORBA/LocalInterfaceDef:1.0"       }, InterfaceDef)
  
--ExtAttributeDef         = oo.class({ __idltype = "IDL:omg.org/CORBA/ExtAttributeDef:1.0"         }, AttributeDef)
--ExtValueDef             = oo.class({ __idltype = "IDL:omg.org/CORBA/ExtValueDef:1.0"             }, ValueDef)
--ExtInterfaceDef         = oo.class({ __idltype = "IDL:omg.org/CORBA/ExtInterfaceDef:1.0"         }, InterfaceDef, InterfaceAttrExtension)
--ExtAbstractInterfaceDef = oo.class({ __idltype = "IDL:omg.org/CORBA/ExtAbstractInterfaceDef:1.0" }, AbstractInterfaceDef, InterfaceAttrExtension)
--ExtLocalInterfaceDef    = oo.class({ __idltype = "IDL:omg.org/CORBA/ExtLocalInterfaceDef:1.0"    }, LocalInterfaceDef, InterfaceAttrExtension)
  
  ObjectRef               = oo.class({}, PrimitiveDef) -- fake class

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Empty = setmetatable({}, { __newindex = function(_, field) error("attempt to set table 'Empty'") end })

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function topdown(stack, class)
	while stack[class] do
		local ready = true
		for _, super in oo.supers(stack[class]) do
			if stack:insert(super, class) then
				ready = false
				break
			end
		end
	 	if ready then return stack[class] end
	end
end
local function iconstruct(class)
	local stack = OrderedSet()
	stack:push(class)
	return topdown, stack, OrderedSet.firstkey
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--
-- Implementation
--
local DefaultRegistry = oo.class()
function DefaultRegistry:__index(...) return ... end

function IRObject:__init(definition, registry)
	registry = registry or DefaultRegistry()
	local object
	local repository = definition.containing_repository
	object = repository.definition_map[definition.repID]
	if object ~= definition then                                                  --[[VERBOSE]] verbose:repository(true, definition._type," ",definition.repID or definition.name)
		object = oo.rawnew(self, object)
		object.containing_repository = repository
		object.dependencies = object.dependencies or {}
		registry[definition] = object
		registry[object] = object
		for class in iconstruct(self) do
			local fields = rawget(class, "definition_fields")
			if fields then
				for name, field in pairs(fields) do
					if definition[name] ~= nil or not field.optional then
						if type(field.type) == "string" then
							assert.type(definition[name], field.type, name)
						else
							definition[name] = registry[ definition[name] ]
						end
					end
				end
			end
			local update = rawget(class, "update")
			if update then
				update(object, definition, registry)
			end
		end                                                                         --[[VERBOSE]] verbose:repository(false)
	end
	return object
end

--TODO:[maia] add calls to these function and manage depencies properly

function IRObject:associate(object, field)
	local dependencies = object.dependencies
	if dependencies then
		--if not dependencies[self] then
		--	dependencies[self] = {}
		--end
		--dependencies[self][field] = true
		if dependencies[self] and dependencies[self] ~= field then
			assert.error("Êpa! Isso não deveria acontecer:"..dependencies[self].." -> "..field)
		end
		dependencies[self] = field
	end
	return object
end

function IRObject:desassociate(object, field)
	local dependencies = object.dependencies
	if dependencies then
		--dependencies[self][field] = nil
		--if next(dependencies[self]) == nil then
		--	dependencies[self] nil
		--end
		dependencies[self] = nil
	end
end

--
-- Operations
--
function IRObject:destroy()
	assert.exception{ "BAD_INV_ORDER", minor_error_code = 1,
		message = "attempt to destroy IR definition (currently not allowed)",
		reason = "irdestroy",
		object = self,
	}
end

--------------------------------------------------------------------------------

--
-- Implementation
--
Contained.version    = "1.0"
Contained.definition_fields = {
	repID                 = { type = "string", optional = true },
	containing_repository = { type = Repository },
	defined_in            = { type = Container, optional = true },
	version               = { type = "string", optional = true },
	name                  = { type = "string" },
}

function Contained:update(new)
	new.defined_in = new.defined_in or new.containing_repository
	if new.defined_in.containing_repository ~= self.containing_repository then
		assert.illegal(defined_in,
		              "container, repository does not match",
		              "BAD_PARAM")
	end
	if new.repID then self:_set_id(new.repID) end
	self:move(new.defined_in, new.name, new.version)
end

local RepIDFormat = "IDL:%s:%s"
function Contained:updatename()
	self.absolute_name = self.defined_in.absolute_name.."::"..self.name
	if not self.repID then
		self:_set_id(RepIDFormat:format(self.absolute_name:gsub("::", "/"):sub(2),
		                                self.version))
	end
	if self.definitions then
		for name, member in pairs(self.definitions) do
			if oo.instanceof(member, Contained) then
				member:updatename()
			end
		end
	end
end

--
-- Attributes
--
function Contained:_set_id(id)
	local definitions = self.containing_repository.definition_map
	if definitions[id] and definitions[id] ~= self then
		assert.illegal(id, "repository ID, already exists", "BAD_PARAM", 2)
	end
	if self.repID then
		definitions[self.repID] = nil
	end
	self.repID = id
	self.id = id
	definitions[id] = self
end

function Contained:_set_name(name)
	local definitions = self.defined_in.definitions
	if definitions[name] and definitions[name] ~= self then
		assert.illegal(name, "contained name, name clash", "BAD_PARAM", 1)
	end
	if self.name then
		definitions[self.name] = nil
	end
	self.name = name
	definitions[name] = self
	self:updatename()
end

--
-- Operations
--
local ContainedDescription = iridl.Contained.definitions.Description
function Contained:describe()
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

function Contained:move(new_container, new_name, new_version)
	if new_container.containing_repository ~= self.containing_repository then
		assert.illegal(new_container, "container", "BAD_PARAM", 4)
	end
	local oldcontained = new_container.definitions[new_name]
	if oldcontained and oldcontained ~= self then
		assert.illegal(new_name, "contained name, already exists", "BAD_PARAM", 3)
	end
	if self.defined_in then
		self.defined_in.definitions[self.name] = nil
	end
	self.defined_in = new_container
	self.version = new_version
	self:_set_name(new_name)
end

--------------------------------------------------------------------------------

--
-- Implementation
--
Container.definition_fields = {
	definitions = { type = "table", optional = true },
}
function Container:update(new, registry)
	self.definitions = self.expandable and self.definitions or {}
	if new.definitions then
		for name, member in pairs(new.definitions) do
			if type(name) == "string" and not name:match("^_") then
				member = self:associate(registry[member], "definitions")
				member:move(self, name, self.version)
			end
		end
	end
end

local single
local function isingle() return single end
function Container:hierarchy()
	single = self
	return isingle
end

--
-- Read interface
--

function Container:lookup(search_name)
	local scope
	if search_name:find("^::") then
		scope = self.containing_repository
	else
		scope = self
		search_name = "::"..search_name
	end
	for nextscope in string.gmatch(search_name, "::([%w][_%w]*)") do
		if not scope or not scope.definitions then return nil end
		scope = scope.definitions[nextscope]
	end
	return scope
end

function Container:contents(limit_type, exclude_inherited, max_returned_objs)
	max_returned_objs = max_returned_objs or -1
	local contents = {}
	for container in self:hierarchy() do
		for _, list in ipairs{ container.definitions, container.members } do
			for name, member in pairs(list)	do
				if
					type(name) == "string" and not name:match("^_") and
					(limit_type == "dk_all" or member.def_kind == limit_type)
				then
					if max_returned_objs == 0 then break end
					contents[#contents+1] = member
					max_returned_objs = max_returned_objs - 1
				end
			end
		end
		if exclude_inherited then break end
	end
	return contents, max_returned_objs
end

function Container:lookup_name(search_name, levels_to_search,
                               limit_type, exclude_inherited)
	-- TODO:[maia] should return contents in the order they were created
	local results = {}
	for container in self:hierarchy() do
		for _, list in ipairs{ container.definitions, container.members } do
			for name, member in pairs(list)	do
				if
					type(name) == "string" and not name:match("^_") and
					(limit_type == "dk_all" or member.def_kind == limit_type)
				then
					results[#results+1] = member
				end
			end
		end
		if exclude_inherited then break end
	end
	return results
end

local ContainerDescription = iridl.Container.definitions.Description
function Container:describe_contents(limit_type, exclude_inherited,
                                     max_returned_objs)
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
	return contents
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

function IDLType:update()
	self.type = self
end

--------------------------------------------------------------------------------

local PrimitiveTypes = {
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
	pk_objref   = idl.Object("IDL:omg.org/CORBA/Object:1.0"),
}

PrimitiveDef.def_kind = "dk_Primitive"

function PrimitiveDef:__init(definition)
	self = oo.rawnew(self, definition)
	IDLType.update(self)
	return self
end

for kind, type in pairs(PrimitiveTypes) do
	PrimitiveDef(type).kind = kind
end

--------------------------------------------------------------------------------

function ObjectRef:update(new)
	if new.repID ~= ObjectRef.repID then
		assert.illegal(new, "Object type, use interface definition instead")
	end
	return PrimitiveTypes.pk_objref
end

--------------------------------------------------------------------------------

ArrayDef._type = "array"
ArrayDef.def_kind = "dk_Array"
ArrayDef.definition_fields = {
	maxlength   = { type = "number" },
	elementtype = { type = IDLType },
}

function ArrayDef:update(new)
	self.maxlengh = new.maxlengh
	self:_set_element_type_def(new.elementtype)
end

function ArrayDef:_get_element_type() return self.elementtype end

function ArrayDef:_set_element_type_def(type_def)
	self.element_type_def = type_def
	self.elementtype = type_def.type
end

--------------------------------------------------------------------------------

SequenceDef._type = "sequence"
SequenceDef.def_kind = "dk_Sequence"
SequenceDef.maxlength = 0
SequenceDef.definition_fields = {
	maxlength   = { type = "number", optional = true },
	elementtype = { type = IDLType },
}

SequenceDef.update = ArrayDef.update
SequenceDef._get_element_type = ArrayDef._get_element_type
SequenceDef._set_element_type_def = ArrayDef._set_element_type_def
function SequenceDef:_set_bound(value) self.maxlength = value end
function SequenceDef:_get_bound() return self.maxlength end

--------------------------------------------------------------------------------

StringDef._type = "string"
StringDef.def_kind = "dk_String"
StringDef.maxlength = 0
StringDef.definition_fields = {
	maxlength   = { type = "number", optional = true },
}
StringDef._set_bound = SequenceDef._set_bound
StringDef._get_bound = SequenceDef._get_bound

--------------------------------------------------------------------------------

AttributeDef._type = "attribute"
AttributeDef.def_kind = "dk_Attribute"
AttributeDef.definition_fields = {
	defined_in = { type = InterfaceDef },
	readonly   = { type = "boolean", optional = true },
	type       = { type = IDLType },
}

function AttributeDef:update(new)
	self:_set_mode(new.readonly and "ATTR_READONLY" or "ATTR_NORMAL")
	self:_set_type_def(new.type)
end

function AttributeDef:_set_name(name)
	Contained._set_name(self, name)
	self.defined_in.members[name] = self
end

function AttributeDef:_set_mode(value)
	self.mode = value
	self.readonly = (value == "ATTR_READONLY")
end

function AttributeDef:_set_type_def(type_def)
	self.type_def = type_def
	self.type = type_def.type
end

function AttributeDef:get_description()
	return setmetatable({
		type = self.type,
		mode = self.mode,
	}, iridl.AttributeDescription)
end

--------------------------------------------------------------------------------

OperationDef._type = "operation"
OperationDef.def_kind = "dk_Operation"
OperationDef.contexts = Empty
OperationDef.parameters = Empty
OperationDef.inputs = Empty
OperationDef.outputs = Empty
OperationDef.exceptions = Empty
OperationDef.result = idl.void
OperationDef.definition_fields = {
	defined_in = { type = InterfaceDef },
	oneway = { type = "boolean", optional = true },
	contexts = { type = "table", optional = true },
	parameters = { type = "table", optional = true },
	exceptions = { type = "table", optional = true },
	result = { type = IDLType, optional = true },
}

function OperationDef:update(new, registry)
	self:_set_mode(new.oneway and "OP_ONEWAY" or "OP_NORMAL")
	if new.result then
		self:_set_result_def(new.result)
	end
	
	if new.parameters then
		local parameters = {}
		for index, param in ipairs(new.parameters) do
			local type_def = registry[param.type]
			parameters[index] = {
				name = param.name,
				mode = param.mode,
				type_def = type_def,
				type = type_def.type,
			}
		end
		self:_set_params(parameters)
	end
	
	if new.exceptions then
		local exceptions = {}
		for index, except in ipairs(new.exceptions) do
			exceptions[index] = registry[except]
		end
		self:_set_exceptions(exceptions)
	end
	
	self.contexts = new.contexts
end

function OperationDef:_set_name(name)
	Contained._set_name(self, name)
	self.defined_in.members[name] = self
end

function OperationDef:_set_mode(value)
	self.mode = value
	self.oneway = (value == "OP_ONEWAY")
end

function OperationDef:_set_result_def(type_def)
	local current = self.result
	local newval = type_def.type
	if current ~= newval then
		self.result_def = type_def
		self.result = newval
		if current == idl.void then
			if self.outputs == Empty then
				self.outputs = { newval }
			else
				table.insert(self.outputs, 1, newval)
			end
		elseif newval == idl.void then
			table.remove(self.outputs, 1)
		else
			self.outputs[1] = newval
		end
	end
end

function OperationDef:_get_params() return self.parameters end
function OperationDef:_set_params(params)
	local parameters = {}
	local inputs = {}
	local outputs = {}
	if self.result ~= idl.void then
		outputs[#outputs+1] = self.result
	end
	for index, param in ipairs(params) do
		local type = param.type
		local mode = param.mode or "PARAM_IN"
		parameters[index] = {
			name = param.name,
			typedef = param.typedef,
			type = type,
			mode = mode,
		}
		if mode == "PARAM_IN" then
			inputs[#inputs+1] = type
		elseif mode == "PARAM_OUT" then
			outputs[#outputs+1] = type
		elseif mode == "PARAM_INOUT" then
			inputs[#inputs+1] = type
			outputs[#outputs+1] = type
		else
			assert.illegal(mode, "operation parameter mode")
		end
	end
	self.parameters = parameters
	self.inputs = inputs
	self.outputs = outputs
end

function OperationDef:_set_exceptions(excepts)
	local exceptions = {}
	for index, except in ipairs(excepts) do
		exceptions[index] = except
		exceptions[except.repID] = except:get_description().type
	end
	self.exceptions = excepts
end

function OperationDef:get_description()
	return setmetatable({
		result     = self.result,
		mode       = self.mode,
		contexts   = self.contexts,
		parameters = self.parameters,
		exceptions = self.exceptions,
	}, iridl.OperationDescription)
end

--------------------------------------------------------------------------------

TypedefDef._type = "typedef"
TypedefDef.def_kind = "dk_Typedef"

function TypedefDef:get_description()
	return setmetatable({ type = self.type }, iridl.TypeDescription)
end

--------------------------------------------------------------------------------

StructDef._type = "struct"
StructDef.def_kind = "dk_Struct"
StructDef.fields = Empty
StructDef.definition_fields = {
	fields = { type = "table", optional = true },
}

function StructDef:update(new, registry)
	if new.fields then
		local fields = {}
		for index, field in ipairs(new.fields) do
			local type_def = registry[field.type]
			fields[index] = {
				name = field.name,
				type_def = type_def,
				type = type_def.type,
			}
		end
		self:_set_members(fields)
	end
end

StructDef._set_type_def = AttributeDef._set_type_def

function StructDef:_get_members() return self.fields end
function StructDef:_set_members(members)
	local fields = {}
	for index, member in ipairs(members) do
		fields[index] = {
			name = member.name,
			type = member.type,
			type_def = member.type_def,
		}
	end
	self.fields = fields
end

--------------------------------------------------------------------------------

UnionDef._type = "union"
UnionDef.def_kind = "dk_Union"
UnionDef.default = -1
UnionDef.options = Empty
UnionDef.members = Empty
UnionDef.definition_fields = {
	switch = { type = IDLType },
	options = { type = "table", optional = true },
	default = { type = "number", optional = true },
}

function UnionDef:update(new, registry)
	self:_set_discriminator_type_def(new.switch)
	
	if new.options then
		local members = {}
		for index, option in ipairs(new.options) do
			local type_def = registry[option.type]
			members[index] = {
				name = option.name,
				label = setmetatable({ option.label }, self.switch),
				type_def = type_def,
				type = type_def.type,
			}
		end
		self:_set_members(members)
	end
end

function UnionDef:_get_discriminator_type() return self.switch end

function UnionDef:_set_discriminator_type_def(type_def)
	self.discriminator_type_def = type_def
	self.switch = type_def.type
end

function UnionDef:_set_members(members)
	local options = {}
	local selector = {}
	local selection = {}
	for index, member in ipairs(members) do
		local option = {
			label = member.label._anyval,
			name = member.name,
			type = member.type,
			type_def = member.type_def,
		}
		options[index] = option
		selector[option.name] = option.label
		selection[option.label] = option
	end
	self.options = options
	self.selector = selector
	self.selection = selection
	self.members = members
end

--------------------------------------------------------------------------------

EnumDef._type = "enum"
EnumDef.def_kind = "dk_Enum"
EnumDef.definition_fields = {
	enumvalues = { type = "table" },
}

function EnumDef:update(new)
	self:_set_members(new.enumvalues)
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

AliasDef._type = "typedef"
AliasDef.def_kind = "dk_Alias"
AliasDef.definition_fields = {
	type = { type = IDLType },
}

function AliasDef:update(new)
	self:_set_original_type_def(new.type)
end

function AliasDef:_set_original_type_def(type_def)
	self.original_type_def = type_def
	self.type = type_def.type
end

--------------------------------------------------------------------------------

Repository.def_kind = "dk_Repository"
Repository.repID = ""
Repository.absolute_name = ""

function Repository:__init(object)
	self = oo.rawnew(self, object)
	self.containing_repository = self.containing_repository or self
	self.definition_map        = self.definition_map or {}
	Container.update(self, self)
	return self
end

--
-- Read interface
--

function Repository:lookup_id(search_id)
	return self.definition_map[search_id]
end

--function Repository:get_canonical_typecode(tc)
--end

function Repository:get_primitive(kind)
	return PrimitiveTypes[kind]
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

ModuleDef._type = "module"
ModuleDef.def_kind = "dk_Module"
ModuleDef.expandable = true

function ModuleDef:get_description()
	return setmetatable({}, iridl.ModuleDescription)
end

--------------------------------------------------------------------------------

ExceptionDef._type = "except"
ExceptionDef.def_kind = "dk_Exception"
ExceptionDef.members = Empty
ExceptionDef.definition_fields = {
	members = { type = "table", optional = true },
}

function ExceptionDef:update(new, registry)
	self.type = self
	if new.members then
		local members = {}
		for index, member in ipairs(new.members) do
			local type_def = registry[member.type]
			members[index] = {
				name = member.name,
				type_def = type_def,
				type = type_def.type,
			}
		end
		self.members = members
	end
end

function ExceptionDef:get_description()
	return setmetatable({ type = self }, iridl.ExceptionDescription)
end

--------------------------------------------------------------------------------

InterfaceDef._type = "interface"
InterfaceDef.def_kind = "dk_Interface"
InterfaceDef.base_interfaces = Empty
InterfaceDef.members = Empty
InterfaceDef.definition_fields = {
	base_interfaces = { type = "table", optional = true },
	members = { type = "table", optional = true },
}

InterfaceDef.hierarchy = idl.basesof

function InterfaceDef:update(new, registry)
	self.members = {}
	if new.members then
		for name, member in pairs(new.members) do
			if type(name) == "string" then
				self.members[member.name] = registry[member]
			end
		end
	end
	if new.base_interfaces then
		local base_interfaces = {}
		for index, base in ipairs(new.base_interfaces) do
			base_interfaces[index] = registry[base]
		end
		self:_set_base_interfaces(base_interfaces)
	end
end

function InterfaceDef:get_description()
	local base_interfaces = {}
	for index, base in ipairs(self.base_interfaces) do
		base_interfaces[index] = base.repID
	end
	return setmetatable({ base_interfaces = base_interfaces },
	                    iridl.InterfaceDescription)
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
function InterfaceDef:describe_interface()
	local operations = {}
	local attributes = {}
	local base_interfaces = {}
	for index, base in ipairs(self.base_interfaces) do
		base_interfaces[index] = base.repID
	end
	for base in self:hierarchy() do
		for _, member in pairs(base.members) do
			if member._type == "attribute" then
				attributes[#attributes+1] = member:describe().value
			elseif member._type == "operation" and not member.name:match("^_") then
				operations[#operations+1] = member:describe().value
			end
		end
	end
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
	for _, interface in ipairs(bases) do
		for base in interface:hierarchy() do
			for _, member in pairs(base.members) do
				if self.members[member.name] then
					assert.illegal(bases,
					               "base interfaces, member '"..
					               member.name..
					               "' override not allowed",
					               "BAD_PARAM", 5)
				end
			end
		end
	end
	self.base_interfaces = bases
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
-- Implementation --------------------------------------------------------------

oo.class(_M, Repository)

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

--------------------------------------------------------------------------------

local Registry = oo.class()

function Registry:__init(object)
	self = oo.rawnew(self, object)
	self[PrimitiveTypes.pk_null    ] = PrimitiveTypes.pk_null
	self[PrimitiveTypes.pk_void    ] = PrimitiveTypes.pk_void
	self[PrimitiveTypes.pk_short   ] = PrimitiveTypes.pk_short
	self[PrimitiveTypes.pk_long    ] = PrimitiveTypes.pk_long
	self[PrimitiveTypes.pk_ushort  ] = PrimitiveTypes.pk_ushort
	self[PrimitiveTypes.pk_ulong   ] = PrimitiveTypes.pk_ulong
	self[PrimitiveTypes.pk_float   ] = PrimitiveTypes.pk_float
	self[PrimitiveTypes.pk_double  ] = PrimitiveTypes.pk_double
	self[PrimitiveTypes.pk_boolean ] = PrimitiveTypes.pk_boolean
	self[PrimitiveTypes.pk_char    ] = PrimitiveTypes.pk_char
	self[PrimitiveTypes.pk_octet   ] = PrimitiveTypes.pk_octet
	self[PrimitiveTypes.pk_any     ] = PrimitiveTypes.pk_any
	self[PrimitiveTypes.pk_TypeCode] = PrimitiveTypes.pk_TypeCode
	self[PrimitiveTypes.pk_string  ] = PrimitiveTypes.pk_string
	self[PrimitiveTypes.pk_objref  ] = PrimitiveTypes.pk_objref
	self[self.repository           ] = self.repository
	return self
end

function Registry:__index(definition)
	local class = Classes[definition._type]
	definition.containing_repository = self.repository
	definition = class(definition, self)
	return definition
end

--------------------------------------------------------------------------------

function register(self, ...)
	local repository = self
	local registry = Registry{ repository = self }
	local results = {}
	local count = select("#", ...)
	for i = 1, count do
		local definition = select(i, ...)
		assert.type(definition, "table", "IR object definition")
		results[i] = registry[definition]
	end
	return unpack(results, 1, count)
end

function resolve(self, typeref)
	if type(typeref) == "string" then
		return self:lookup(typeref) or
		       self:lookup_id(typeref) or
		       assert.exception{ "INTERNAL", minor_code_value = 0,
		       	reason = "interface",
		       	message = "unknown interface with reference",
		       	reference = type,
		       }
	elseif typeref._type == "interface" then
		return self:register(typeref)
	else
		assert.exception{ "INTERNAL", minor_code_value = 0,
			reason = "interface",
			message = "illegal IDL type",
			type = typeref,
		}
	end
end
