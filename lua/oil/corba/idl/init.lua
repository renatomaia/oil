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
-- Title  : Interface Definition Language (IDL) specifications in Lua         --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   istype(object)        Checks whether object is an IDL type               --
--   isspec(object)        Checks whether object is an IDL specification      --
--                                                                            --
--   null                  IDL null type                                      --
--   void                  IDL void type                                      --
--   short                 IDL integer type short                             --
--   long                  IDL integer type long                              --
--   ushort                IDL integer type unsigned short                    --
--   ulong                 IDL integer type unsigned long                     --
--   float                 IDL floating-point numeric type                    --
--   double                IDL double-precision floating-point numeric type   --
--   boolean               IDL boolean type                                   --
--   char                  IDL character type                                 --
--   octet                 IDL raw byte type                                  --
--   any                   IDL generic type                                   --
--   TypeCode              IDL meta-type                                      --
--   string                IDL string type                                    --
--                                                                            --
--   Object(definition)    IDL Object type construtor                         --
--   struct(definition)    IDL struct type construtor                         --
--   union(definition)     IDL union type construtor                          --
--   enum(definition)      IDL enumeration type construtor                    --
--   sequence(definition)  IDL sequence type construtor                       --
--   array(definition)     IDL array type construtor                          --
--   typedef(definition)   IDL type definition construtor                     --
--   except(definition)    IDL expection construtor                           --
--                                                                            --
--   attribute(definition) IDL attribute construtor                           --
--   operation(definition) IDL operation construtor                           --
--   module(definition)    IDL module structure constructor                   --
--   interface(definition) IDL object interface structure constructor         --
--                                                                            --
--   OctetSequence         IDL type used in OiL implementation                --
--   Version               IDL type used in OiL implementation                --
--                                                                            --
--   ScopeMemberList       Class that defines behavior of interface member list-
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   The syntax used for description of IDL specifications is strongly based  --
--   on the work provided by Letícia Nogeira (i.e. LuaRep), which was mainly  --
--   inteded to provide an user-friendly syntax. This approach may change to  --
--   allow better fitting into CORBA model, since the use of LuaIDL parsing   --
--   facilities already provides an user-friendly way to define IDL           --
--   specifications. However backward compatibility may be provided whenever  --
--   possible.                                                                --
--------------------------------------------------------------------------------

local type     = type
local newproxy = newproxy
local pairs    = pairs
local ipairs   = ipairs
local rawset   = rawset
local require  = require
local rawget   = rawget

-- backup of string package functions to avoid name crash with string IDL type
local match = require("string").match
local table = require "table"

local OrderedSet = require "loop.collection.OrderedSet"

local oo     = require "oil.oo"
local assert = require "oil.assert"

module "oil.corba.idl"                                                          --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- IDL element types -----------------------------------------------------------

-- TODO:[maia] Why all type names are blank by default?
local DefaultTypeName = ""

local BasicTypes = {
	null       = true,
	void       = true,
	short      = true,
	long       = true,
	longlong   = true,
	ushort     = true,
	ulong      = true,
	ulonglong  = true,
	float      = true,
	double     = true,
	longdouble = true,
	boolean    = true,
	char       = true,
	octet      = true,
	any        = true,
	TypeCode   = true,
}

local UserTypes = {
	string    = true,
	Object    = true,
	struct    = true,
	union     = true,
	enum      = true,
	sequence  = true,
	array     = true,
	typedef   = true,
	except    = true,
	interface = true,
}

local InterfaceElements = {
	attribute = true,
	operation = true,
	module    = true,
}

--------------------------------------------------------------------------------
-- Auxilary module functions ---------------------------------------------------

function istype(object)
	return type(object) == "table" and (
	       	BasicTypes[object._type] == object or
	       	UserTypes[object._type]
	       )
end

function isspec(object)
	return type(object) == "table" and (
	       	BasicTypes[object._type] == object or
	       	UserTypes[object._type] or
	       	InterfaceElements[object._type]
	       )
end

assert.TypeCheckers["idl type"]    = istype
assert.TypeCheckers["idl def."]    = isspec
assert.TypeCheckers["^idl (%l+)$"] = function(value, name)
	if istype(value)
		then return (value._type == name), ("idl "..name.." type")
		else return false, name
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function checkfield(field)
	assert.type(field.name, "string", "field name")
	assert.type(field.type, "idl type", "field type")
end

local function checkfields(fields)
	for _, field in ipairs(fields) do checkfield(field) end
end

--------------------------------------------------------------------------------
-- Basic types -----------------------------------------------------------------

for name in pairs(BasicTypes) do
	local basictype = {_type = name}
	_M[name] = basictype
	BasicTypes[name] = basictype
end

--------------------------------------------------------------------------------
-- Scoped definitions management -----------------------------------------------

local DefinitionList = oo.class()

local function updatenames(idldef)
	local container = idldef.defined_in
	local version = idldef.version
	if container then
		local start, default = match(container.repID, "^(IDL:.*):(%d+%.%d+)$")
		if not start then
			assert.illegal(container.repID, "parent scope repository ID")
		end
		rawset(idldef, "repID", start.."/"..idldef.name..":"..(version or default))
	elseif idldef.name then
		if not version then version = "1.0" end
		rawset(idldef, "repID", "IDL:"..idldef.name..":"..version)
	end
	for _, member in pairs(idldef) do
		if oo.classof(member) == DefinitionList then
			for name, member in pairs(member) do
				if type(name) == "string" then
					updatenames(member)
				end
			end
		end
	end
	return idldef.repID
end

local ScopeKey = newproxy()

function DefinitionList:__init(list, scope)
	if list then
		local members = {}
		for field, value in pairs(list) do
			if type(field) == "string" and isspec(value) then
				members[field] = value
			end
		end
		rawset(list, ScopeKey, scope)
		for field, value in pairs(members) do
			self.__newindex(list, field, value)
		end
	else
		list = { [ScopeKey] = scope }
	end
	return oo.rawnew(self, list)
end

function DefinitionList:__newindex(name, value)
	if isspec(value) then
		value.defined_in = self[ScopeKey]
		if type(name) == "string"
			then value.name = name
			else name = value.name
		end
		updatenames(value)
	end
	return rawset(self, name, value)
end

--------------------------------------------------------------------------------

local function newdef(def, scope)
	assert.type(def, "table", "IDL definition")
	if def.name  == nil then def.name = DefaultTypeName end
	if def.repID == nil then updatenames(def) end
	assert.type(def.name, "string", "IDL definition name")
	assert.type(def.repID, "string", "repository ID")
	if scope then
		def.definitions = DefinitionList(def.definitions, def)
		assert.type(def.definitions, "table", "scoped definition list")
	end
end

--------------------------------------------------------------------------------
-- User-defined type constructors ----------------------------------------------

-- Note: internal structure is optimized for un/marshalling.

string = { _type = "string", maxlength = 0 }

function Object(def)
	if type(def) == "string"
		then def = {repID = def}
		else assert.type(def, "table", "Object type definition")
	end
	assert.type(def.repID, "string", "Object type repository ID")
	if def.repID == "IDL:omg.org/CORBA/Object:1.0"
		then def = object
		else def._type = "Object"
	end
	return def
end

function struct(def)
	newdef(def, true)
	if def.fields == nil then def.fields = def end
	checkfields(def.fields)
	def._type = "struct"
	return def
end

function union(def)
	newdef(def, true)
	if def.default == nil then def.default = -1 end -- indicates no default in CDR
	assert.type(def.switch, "idl type", "union type discriminant")
	assert.type(def.options, "table", "union options definition")
	
	def.selector = {} -- maps field names to labels (option selector)
	def.selection = {} -- maps labels (option selector) to options
	for _, option in ipairs(def.options) do
		checkfield(option)
		if option.label == nil then assert.illegal(nil, "option label value") end
		def.selector[option.name] = option.label
		def.selection[option.label] = option
	end

	function def:__index(field)
		if rawget(self, "_switch") == def.selector[field] then
			return rawget(self, "_value")
		end
	end
	function def:__newindex(field, value)
		local label = def.selector[field]
		if label then
			rawset(self, "_switch", label)
			rawset(self, "_value", value)
			rawset(self, "_field", field)
		end
	end

	def._type = "union"
	return def
end

function enum(def)
	newdef(def)
	if def.enumvalues == nil then def.enumvalues = def end
	assert.type(def.enumvalues, "table", "enumeration values definition")

	def.labelvalue = {}
	for index, label in ipairs(def.enumvalues) do
		assert.type(label, "string", "enumeration value label")
		def.labelvalue[label] = index - 1
	end

	def._type = "enum"
	return def
end

function sequence(def)
	if def.maxlength   == nil then def.maxlength = 0 end
	if def.elementtype == nil then def.elementtype = def[1] end
	assert.type(def.maxlength, "number", "sequence type maximum length ")
	assert.type(def.elementtype, "idl type", "sequence element type")
	def._type = "sequence"
	return def
end

function array(def)
	assert.type(def.length, "number", "array type length")
	if def.elementtype == nil then def.elementtype = def[1] end
	assert.type(def.elementtype, "idl type", "array element type")
	def._type = "array"
	return def
end

function typedef(def)
	newdef(def)
	if def.type  == nil then def.type  = def[1] end
	assert.type(def.type, "idl type", "type in typedef definition")
	def._type = "typedef"
	return def
end

function except(def)
	newdef(def, true)
	if def.members == nil then def.members = def end
	checkfields(def.members)
	def._type = "except"
	return def
end

--------------------------------------------------------------------------------
-- IDL interface definitions ---------------------------------------------------

-- Note: construtor syntax is optimized for use with Interface Repository

function attribute(def)
	newdef(def)
	if def.type  == nil then def.type = def[1] end
	assert.type(def.type, "idl type", "attribute type")

	local mode = def.mode
	if mode == "ATTR_READONLY" then
		def.readonly = true
	elseif mode ~= nil and mode ~= "ATTR_NORMAL" then
		assert.illegal(def.mode, "attribute mode")
	end
	
	def._type = "attribute"
	return def
end

function operation(def)
	newdef(def)
	
	local mode = def.mode
	if mode == "OP_ONEWAY" then
		def.oneway = true
	elseif mode ~= nil and mode ~= "OP_NORMAL" then
		assert.illegal(def.mode, "operation mode")
	end

	def.inputs = {}
	def.outputs = {}
	if def.result and def.result ~= void then
		table.insert(def.outputs, def.result)
	end
	if def.parameters then
		for _, param in ipairs(def.parameters) do
			checkfield(param)
			if param.mode then
				assert.type(param.mode, "string", "operation parameter mode")
				if param.mode == "PARAM_IN" then
					table.insert(def.inputs, param.type)
				elseif param.mode == "PARAM_OUT" then
					table.insert(def.outputs, param.type)
				elseif param.mode == "PARAM_INOUT" then
					table.insert(def.inputs, param.type)
					table.insert(def.outputs, param.type)
				else
					assert.illegal(param.mode, "operation parameter mode")
				end
			else
				table.insert(def.inputs, param.type)
			end
		end
	end

	if def.exceptions then
		for _, except in ipairs(def.exceptions) do
			assert.type(except, "idl except", "raised exception")
			if def.exceptions[except.repID] ~= nil then
				assert.illegal(except.repID,
					"exception raise defintion, got duplicated repository ID")
			end
			def.exceptions[except.repID] = except
		end
	else
		def.exceptions = {}
	end

	def._type = "operation"
	return def
end

function module(def)
	newdef(def, true)
	def._type = "module"
	return def
end

--------------------------------------------------------------------------------

local function ibases(queue, interface)
	interface = queue[interface]
	if interface then
		for _, base in ipairs(interface.base_interfaces) do
			queue:enqueue(base)
		end
		return interface
	end
end
function basesof(interface)
	local queue = OrderedSet()
	queue:enqueue(interface)
	return ibases, queue, OrderedSet.firstkey
end

function interface(def)
	newdef(def, true)
	if def.base_interfaces == nil then def.base_interfaces = def end
	def.members = DefinitionList(def.members, def)
	assert.type(def.base_interfaces, "table", "base interface list")
	assert.type(def.members, "table", "interface member list")
	def._type = "interface"
	def.hierarchy = basesof
	return def
end

--------------------------------------------------------------------------------
-- IDL types used in the implementation of OiL ---------------------------------

object = interface{
	repID = "IDL:omg.org/CORBA/Object:1.0",
	name = "Object",
}
OctetSeq = sequence{octet}
Version = struct{{ type = octet, name = "major" },
                 { type = octet, name = "minor" }}
