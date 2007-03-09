local idl = require "oil.corba.idl"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.idl.ir"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local short     = idl.short
local ushort    = idl.ushort
local long      = idl.long
local ulong     = idl.ulong
local boolean   = idl.boolean
local string    = idl.string
local TypeCode  = idl.TypeCode
local any       = idl.any
local enum      = idl.enum
local typedef   = idl.typedef
local struct    = idl.struct
local sequence  = idl.sequence
local module    = idl.module
local interface = idl.interface
local attribute = idl.attribute
local operation = idl.operation

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

module{
	name = "CORBA",
	repID = "IDL:omg.org/CORBA:1.0",
	definitions = _M,
}

Identifier   = typedef{string}
ScopedName   = typedef{string}
RepositoryId = typedef{string}

DefinitionKind = enum{
	"dk_none",
	"dk_all",
	"dk_Attribute", "dk_Constant", "dk_Exception", "dk_Interface",
	"dk_Module", "dk_Operation", "dk_Typedef",
	"dk_Alias", "dk_Struct", "dk_Union", "dk_Enum",
	"dk_Primitive", "dk_String", "dk_Sequence", "dk_Array",
	"dk_Repository",
	"dk_Wstring", "dk_Fixed",
	"dk_Value", "dk_ValueBox", "dk_ValueMember",
	"dk_Native",
	"dk_AbstractInterface",
	"dk_LocalInterface",
	"dk_Component", "dk_Home",
	"dk_Factory", "dk_Finder",
	"dk_Emits", "dk_Publishes", "dk_Consumes",
	"dk_Provides", "dk_Uses",
	"dk_Event"
}

IRObject = interface{
	members = {
		-- read interface
		def_kind = attribute{ DefinitionKind, readonly = true },
		-- write interface
		destroy = operation{},
	},
}

VersionSpec = typedef{string}

Contained  = interface{}
Repository = interface{}
Container  = interface{}

Contained.base_interfaces = { IRObject }

-- read/write interface

Contained.members.id      = attribute{ RepositoryId }
Contained.members.name    = attribute{ Identifier   }
Contained.members.version = attribute{ VersionSpec  }

-- read interface

Contained.members.defined_in            = attribute{ Container , readonly=true }
Contained.members.absolute_name         = attribute{ ScopedName, readonly=true }
Contained.members.containing_repository = attribute{ Repository, readonly=true }

Contained.definitions.Description = struct{
	{ type = DefinitionKind, name = "kind"  },
	{ type = any           , name = "value" },
}

Contained.members.describe = operation{ result = Contained.definitions.Description }

-- write interface

Contained.members.move = operation{
	parameters = {
		{ type = Container  , name = "new_container" },
		{ type = Identifier , name = "new_name"      },
		{ type = VersionSpec, name = "new_version"   },
	},
}

ModuleDef               = interface{}
ConstantDef             = interface{}
IDLType                 = interface{}
StructDef               = interface{}
UnionDef                = interface{}
EnumDef                 = interface{}
AliasDef                = interface{}
InterfaceDef            = interface{}
ExceptionDef            = interface{}
NativeDef               = interface{}
ValueDef                = interface{}
ValueBoxDef             = interface{}
AbstractInterfaceDef    = interface{}
LocalInterfaceDef       = interface{}
ExtInterfaceDef         = interface{}
ExtValueDef             = interface{}
ExtAbstractInterfaceDef = interface{}
ExtLocalInterfaceDef    = interface{}

InterfaceDefSeq            = typedef{ sequence{InterfaceDef           } }
ValueDefSeq                = typedef{ sequence{ValueDef               } }
AbstractInterfaceDefSeq    = typedef{ sequence{AbstractInterfaceDef   } }
LocalInterfaceDefSeq       = typedef{ sequence{LocalInterfaceDef      } }
ExtInterfaceDefSeq         = typedef{ sequence{ExtInterfaceDef        } }
ExtValueDefSeq             = typedef{ sequence{ExtValueDef            } }
ExtAbstractInterfaceDefSeq = typedef{ sequence{ExtAbstractInterfaceDef} }
ExtLocalInterfaceDefSeq    = typedef{ sequence{ExtLocalInterfaceDef   } }

StructMember = struct{
	{ type = Identifier, name = "name"     },
	{ type = TypeCode  , name = "type"     },
	{ type = IDLType   , name = "type_def" },
}
StructMemberSeq = typedef{ sequence{StructMember} }

ContainedSeq = typedef{ sequence{Contained} }

Initializer = struct{
	{ type = StructMemberSeq, name = "members" },
	{ type = Identifier     , name = "name"    },
}
InitializerSeq = typedef{ sequence{Initializer} }

ExceptionDescription = struct{
	{ type = Identifier  , name = "name"       },
	{ type = RepositoryId, name = "id"         },
	{ type = RepositoryId, name = "defined_in" },
	{ type = VersionSpec , name = "version"    },
	{ type = TypeCode    , name = "type"       },
}
ExcDescriptionSeq = typedef{ sequence{ExceptionDescription} }

ExtInitializer = struct{
	{ type = StructMemberSeq  , name = "members"    },
	{ type = ExcDescriptionSeq, name = "exceptions" },
	{ type = Identifier       , name = "name"       },
}
ExtInitializerSeq = typedef{ sequence{ExtInitializer} }

UnionMember = struct{
	{ type = Identifier, name = "name"     },
	{ type = any       , name = "label"    },
	{ type = TypeCode  , name = "type"     },
	{ type = IDLType   , name = "type_def" },
}
UnionMemberSeq = typedef{ sequence{UnionMember} }

EnumMemberSeq = typedef{ sequence{Identifier} }

Container.base_interfaces = { IRObject }

-- read interface

Container.members.lookup = operation{
	result = Contained,
	parameters = {{ type = ScopedName, name = "search_name" }},
}

Container.members.contents = operation{
	result = ContainedSeq,
	parameters = {
		{ type = DefinitionKind, name = "limit_type"        },
		{ type = boolean       , name = "exclude_inherited" },
	},
}

Container.members.lookup_name = operation{
	result = ContainedSeq,
	parameters = {
		{ type = Identifier    , name = "search_name"       },
		{ type = long          , name = "levels_to_search"  },
		{ type = DefinitionKind, name = "limit_type"        },
		{ type = boolean       , name = "exclude_inherited" },
	},
}

Container.definitions.Description = struct{
	{ type = Contained     , name = "contained_object" },
	{ type = DefinitionKind, name = "kind"             },
	{ type = any           , name = "value"            },
}

Container.definitions.DescriptionSeq = typedef{ sequence{Container.definitions.Description} }
Container.members.describe_contents = operation{
	result = Container.definitions.DescriptionSeq,
	parameters = {
		{ type = DefinitionKind, name = "limit_type"        },
		{ type = boolean       , name = "exclude_inherited" },
		{ type = long          , name = "max_returned_objs" },
	},
}

-- write interface

Container.members.create_module = operation {
	result = ModuleDef,
	parameters = {
		{ type = RepositoryId, name = "id"      },
		{ type = Identifier,   name = "name"    },
		{ type = VersionSpec,  name = "version" },
	},
}
Container.members.create_constant = operation {
	result = ConstantDef,
	parameters = {
		{ type = RepositoryId, name = "id"      },
		{ type = Identifier,   name = "name"    },
		{ type = VersionSpec,  name = "version" },
		{ type = IDLType,      name = "type"    },
		{ type = any,          name = "value"   },
	},
}
Container.members.create_struct = operation {
	result = StructDef,
	parameters = {
		{ type = RepositoryId,    name = "id"      },
		{ type = Identifier,      name = "name"    },
		{ type = VersionSpec,     name = "version" },
		{ type = StructMemberSeq, name = "members" },
	},
}
Container.members.create_union = operation {
	result = UnionDef,
	parameters = {
		{ type = RepositoryId,   name = "id"                 },
		{ type = Identifier,     name = "name"               },
		{ type = VersionSpec,    name = "version"            },
		{ type = IDLType,        name = "discriminator_type" },
		{ type = UnionMemberSeq, name = "members"            },
	},
}
Container.members.create_enum = operation {
	result = EnumDef,
	parameters = {
		{ type = RepositoryId,  name = "id"      },
		{ type = Identifier,    name = "name"    },
		{ type = VersionSpec,   name = "version" },
		{ type = EnumMemberSeq, name = "members" },
	},
}
Container.members.create_alias = operation {
	result = AliasDef,
	parameters = {
		{ type = RepositoryId, name = "id"            },
		{ type = Identifier,   name = "name"          },
		{ type = VersionSpec,  name = "version"       },
		{ type = IDLType,      name = "original_type" },
	},
}
Container.members.create_interface = operation {
	result = InterfaceDef,
	parameters = {
		{ type = RepositoryId,    name = "id"              },
		{ type = Identifier,      name = "name"            },
		{ type = VersionSpec,     name = "version"         },
		{ type = InterfaceDefSeq, name = "base_interfaces" },
	},
}
Container.members.create_value = operation{
	result = ValueDef,
	parameters = {
		{ type = RepositoryId,    name = "id"                   },
		{ type = Identifier,      name = "name"                 },
		{ type = VersionSpec,     name = "version"              },
		{ type = boolean,         name = "is_custom"            },
		{ type = boolean,         name = "is_abstract"          },
		{ type = ValueDef,        name = "base_value"           },
		{ type = boolean,         name = "is_truncatable"       },
		{ type = ValueDefSeq,     name = "abstract_base_values" },
		{ type = InterfaceDefSeq, name = "supported_interfaces" },
		{ type = InitializerSeq,  name = "initializers"         },
	},
}
Container.members.create_value_box = operation{
	result = ValueBoxDef,
	parameters = {
		{ type = RepositoryId, name = "id"                },
		{ type = Identifier,   name = "name"              },
		{ type = VersionSpec,  name = "version"           },
		{ type = IDLType,      name = "original_type_def" },
	},
}
Container.members.create_exception = operation{
	result = ExceptionDef,
	parameters = {
		{ type = RepositoryId,    name = "id"      },
		{ type = Identifier,      name = "name"    },
		{ type = VersionSpec,     name = "version" },
		{ type = StructMemberSeq, name = "members" },
	},
}
Container.members.create_native = operation{
	result = NativeDef,
	parameters = {
		{ type = RepositoryId, name = "id"      },
		{ type = Identifier,   name = "name"    },
		{ type = VersionSpec,  name = "version" },
	},
}
Container.members.create_abstract_interface = operation {
	result = AbstractInterfaceDef,
	parameters = {
		{ type = RepositoryId,            name = "id"              },
		{ type = Identifier,              name = "name"            },
		{ type = VersionSpec,             name = "version"         },
		{ type = AbstractInterfaceDefSeq, name = "base_interfaces" },
	},
}
Container.members.create_local_interface = operation {
	result = LocalInterfaceDef,
	parameters = {
		{ type = RepositoryId,    name = "id"              },
		{ type = Identifier,      name = "name"            },
		{ type = VersionSpec,     name = "version"         },
		{ type = InterfaceDefSeq, name = "base_interfaces" },
	},
}
Container.members.create_ext_value = operation {
	result = ExtValueDef,
	parameters = {
		{ type = RepositoryId,      name = "id"                   },
		{ type = Identifier,        name = "name"                 },
		{ type = VersionSpec,       name = "version"              },
		{ type = boolean,           name = "is_custom"            },
		{ type = boolean,           name = "is_abstract"          },
		{ type = ValueDef,          name = "base_value"           },
		{ type = boolean,           name = "is_truncatable"       },
		{ type = ValueDefSeq,       name = "abstract_base_values" },
		{ type = InterfaceDefSeq,   name = "supported_interfaces" },
		{ type = ExtInitializerSeq, name = "initializers"         },
	},
}

IDLType.base_interfaces = { IRObject }
IDLType.members.type = attribute{ TypeCode, readonly = true }

PrimitiveDef = interface{}
StringDef    = interface{}
SequenceDef  = interface{}
ArrayDef     = interface{}
WstringDef   = interface{}
FixedDef     = interface{}

PrimitiveKind = enum{
	"pk_null", "pk_void", "pk_short", "pk_long", "pk_ushort", "pk_ulong",
	"pk_float", "pk_double", "pk_boolean", "pk_char", "pk_octet",
	"pk_any", "pk_TypeCode", "pk_Principal", "pk_string", "pk_objref",
	"pk_longlong", "pk_ulonglong", "pk_longdouble",
	"pk_wchar", "pk_wstring", "pk_value_base"
}

Repository.base_interfaces = { Container }

-- read interface

Repository.members.lookup_id = operation{
	result = Contained,
	parameters = {{ type = RepositoryId , name = "search_id" }},
}
Repository.members.get_canonical_typecode = operation{
	result = TypeCode,
	parameters = {{ type = TypeCode, name = "tc" }},
}
Repository.members.get_primitive = operation{
	result = PrimitiveDef,
	parameters = {{ type = PrimitiveKind, name = "kind" }},
}

-- write interface

Repository.members.create_string = operation{
	result = StringDef,
	parameters = {{ type = ulong, name = "bound" }},
}
Repository.members.create_wstring = operation{
	result = WstringDef,
	parameters = {{ type = ulong, name = "bound" }},
}
Repository.members.create_sequence = operation{
	result = SequenceDef,
	parameters = {
		{ type = ulong,   name = "bound"        },
		{ type = IDLType, name = "element_type" },
	},
}
Repository.members.create_array = operation{
	result = ArrayDef,
	parameters = {
		{ type = ulong,   name = "length"       },
		{ type = IDLType, name = "element_type" },
	},
}
Repository.members.create_fixed = operation{
	result = FixedDef,
	parameters = {
		{ type = ushort, name = "digits" },
		{ type = short,  name = "scale"  },
	},
}

ModuleDef.base_interfaces = { Container, Contained }

ModuleDescription = struct{
	{ type = Identifier  , name = "name"       },
	{ type = RepositoryId, name = "id"         },
	{ type = RepositoryId, name = "defined_in" },
	{ type = VersionSpec , name = "version"    },
}

ConstantDef.base_interfaces = { Contained }

ConstantDef.members.type     = attribute{ TypeCode, readonly = true }
ConstantDef.members.type_def = attribute{ IDLType }
ConstantDef.members.value    = attribute{ any }

ConstantDescription = struct{
	{ type = Identifier  , name = "name"       },
	{ type = RepositoryId, name = "id"         },
	{ type = RepositoryId, name = "defined_in" },
	{ type = VersionSpec , name = "version"    },
	{ type = TypeCode    , name = "type"       },
	{ type = any         , name = "value"      },
}

TypedefDef = interface{ Contained, IDLType }

TypeDescription = struct{
	{ type = Identifier  , name = "name"       },
	{ type = RepositoryId, name = "id"         },
	{ type = RepositoryId, name = "defined_in" },
	{ type = VersionSpec , name = "version"    },
	{ type = TypeCode    , name = "type"       },
}

StructDef.base_interfaces = { TypedefDef, Container }
StructDef.members.members = attribute{ StructMemberSeq }

UnionDef.base_interfaces = { TypedefDef, Container }
UnionDef.members.discriminator_type     = attribute{ TypeCode, readonly = true }
UnionDef.members.discriminator_type_def = attribute{ IDLType }
UnionDef.members.members                = attribute{ UnionMemberSeq }

EnumDef.base_interfaces = { TypedefDef }
EnumDef.members.members = attribute{ EnumMemberSeq }

AliasDef.base_interfaces = { TypedefDef }
AliasDef.members.original_type_def = attribute{ IDLType }

NativeDef.base_interfaces = { TypedefDef }

PrimitiveDef.base_interfaces = { IDLType }
PrimitiveDef.members.kind = attribute{ PrimitiveKind, readonly = true }

StringDef.base_interfaces = { IDLType }
StringDef.members.bound = attribute{ ulong }

WstringDef.base_interfaces = { IDLType }
WstringDef.members.bound = attribute{ ulong }

FixedDef.base_interfaces = { IDLType }
FixedDef.members.digits = attribute{ ushort }
FixedDef.members.scale = attribute{ short }

SequenceDef.base_interfaces = { IDLType }
SequenceDef.members.bound = attribute{ ulong }
SequenceDef.members.element_type = attribute{ TypeCode, readonly = true }
SequenceDef.members.element_type_def = attribute{ IDLType }

ArrayDef.base_interfaces = { IDLType }
ArrayDef.members.length = attribute{ ulong }
ArrayDef.members.element_type = attribute{ TypeCode, readonly = true }
ArrayDef.members.element_type_def = attribute{ IDLType }

ExceptionDef.base_interfaces = { Contained, Container }
ExceptionDef.members.type = attribute{ TypeCode, readonly = true }
ExceptionDef.members.members = attribute{ StructMemberSeq }

AttributeMode = enum{ "ATTR_NORMAL", "ATTR_READONLY" }

AttributeDef = interface{ Contained,
	members = {
		type     = attribute{ TypeCode, readonly = true },
		type_def = attribute{ IDLType },
		mode     = attribute{ AttributeMode },
	},
}

AttributeDescription = struct{
	{ type = Identifier   , name = "name"       },
	{ type = RepositoryId , name = "id"         },
	{ type = RepositoryId , name = "defined_in" },
	{ type = VersionSpec  , name = "version"    },
	{ type = TypeCode     , name = "type"       },
	{ type = AttributeMode, name = "mode"       },
}

ExtAttributeDescription = struct{
	{ type = Identifier       , name = "name"           },
	{ type = RepositoryId     , name = "id"             },
	{ type = RepositoryId     , name = "defined_in"     },
	{ type = VersionSpec      , name = "version"        },
	{ type = TypeCode         , name = "type"           },
	{ type = AttributeMode    , name = "mode"           },
	{ type = ExcDescriptionSeq, name = "get_exceptions" },
	{ type = ExcDescriptionSeq, name = "put_exceptions" },
}

ExtAttributeDef = interface{ AttributeDef }

-- read/write interface

ExtAttributeDef.members.get_exceptions = attribute{ ExcDescriptionSeq }
ExtAttributeDef.members.set_exceptions = attribute{ ExcDescriptionSeq }

-- read interface

ExtAttributeDef.members.describe_attribute = operation{
	result = ExtAttributeDescription,
}

OperationMode = enum{ "OP_NORMAL", "OP_ONEWAY" }
ParameterMode = enum{ "PARAM_IN", "PARAM_OUT", "PARAM_INOUT" }

ParameterDescription = struct{
	{ type = Identifier   , name = "name"     },
	{ type = TypeCode     , name = "type"     },
	{ type = IDLType      , name = "type_def" },
	{ type = ParameterMode, name = "mode"     },
}
ParDescriptionSeq = typedef{ sequence{ParameterDescription} }

ContextIdentifier = typedef{ Identifier }
ContextIdSeq = typedef{ sequence{ContextIdentifier} }
ExceptionDefSeq = typedef{ sequence{ExceptionDef} }

OperationDef = interface { Contained,
	members = {
		result     = attribute{ TypeCode, readonly = true },
		result_def = attribute{ IDLType },
		params     = attribute{ ParDescriptionSeq },
		mode       = attribute{ OperationMode },
		contexts   = attribute{ ContextIdSeq },
		exceptions = attribute{ ExceptionDefSeq },
	},
}

OperationDescription = struct{
	{ type = Identifier       , name = "name"       },
	{ type = RepositoryId     , name = "id"         },
	{ type = RepositoryId     , name = "defined_in" },
	{ type = VersionSpec      , name = "version"    },
	{ type = TypeCode         , name = "result"     },
	{ type = OperationMode    , name = "mode"       },
	{ type = ContextIdSeq     , name = "contexts"   },
	{ type = ParDescriptionSeq, name = "parameters" },
	{ type = ExcDescriptionSeq, name = "exceptions" },
}

RepositoryIdSeq       = typedef{ sequence{RepositoryId}            }
OpDescriptionSeq      = typedef{ sequence{OperationDescription}    }
AttrDescriptionSeq    = typedef{ sequence{AttributeDescription}    }
ExtAttrDescriptionSeq = typedef{ sequence{ExtAttributeDescription} }

InterfaceDef.base_interfaces = { Container, Contained, IDLType }

-- read/write interface

InterfaceDef.members.base_interfaces = attribute{ InterfaceDefSeq }

-- read interface

InterfaceDef.members.is_a = operation{
	result = boolean,
	parameters = {{ type = RepositoryId, name = "interface_id" }},
}
InterfaceDef.definitions.FullInterfaceDescription = struct{
	{ type = Identifier        , name = "name"            },
	{ type = RepositoryId      , name = "id"              },
	{ type = RepositoryId      , name = "defined_in"      },
	{ type = VersionSpec       , name = "version"         },
	{ type = OpDescriptionSeq  , name = "operations"      },
	{ type = AttrDescriptionSeq, name = "attributes"      },
	{ type = RepositoryIdSeq   , name = "base_interfaces" },
	{ type = TypeCode          , name = "type"            },
}
InterfaceDef.members.describe_interface = operation{
	result = InterfaceDef.definitions.FullInterfaceDescription
}

-- write interface

InterfaceDef.members.create_attribute = operation{
	result = AttributeDef,
	parameters = {
		{ type = RepositoryId , name = "id"      },
		{ type = Identifier   , name = "name"    },
		{ type = VersionSpec  , name = "version" },
		{ type = IDLType      , name = "type"    },
		{ type = AttributeMode, name = "mode"    },
	},
}

InterfaceDef.members.create_operation = operation{
	result = OperationDef,
	parameters = {
		{ type = RepositoryId     , name = "id"         },
		{ type = Identifier       , name = "name"       },
		{ type = VersionSpec      , name = "version"    },
		{ type = IDLType          , name = "result"     },
		{ type = OperationMode    , name = "mode"       },
		{ type = ParDescriptionSeq, name = "params"     },
		{ type = ExceptionDefSeq  , name = "exceptions" },
		{ type = ContextIdSeq     , name = "contexts"   },
	},
}

-- TODO:[maia] find where this definition is used!
InterfaceDescription = struct{
	{ type = Identifier     , name = "name"            },
	{ type = RepositoryId   , name = "id"              },
	{ type = RepositoryId   , name = "defined_in"      },
	{ type = VersionSpec    , name = "version"         },
	{ type = RepositoryIdSeq, name = "base_interfaces" },
}

InterfaceAttrExtension = interface{}

InterfaceAttrExtension.definitions.ExtFullInterfaceDescription = struct{
	{ type = Identifier           , name = "name"            },
	{ type = RepositoryId         , name = "id"              },
	{ type = RepositoryId         , name = "defined_in"      },
	{ type = VersionSpec          , name = "version"         },
	{ type = OpDescriptionSeq     , name = "operations"      },
	{ type = ExtAttrDescriptionSeq, name = "attributes"      },
	{ type = RepositoryIdSeq      , name = "base_interfaces" },
	{ type = TypeCode             , name = "type"            },
}

-- read interface
InterfaceAttrExtension.members.describe_ext_interface = operation{
	result = InterfaceAttrExtension.definitions.ExtFullInterfaceDescription,
}

-- write interface
InterfaceAttrExtension.members.create_ext_attribute = operation{
	result = ExtAttributeDef,
	parameters = {
		{ type = RepositoryId   , name = "id"             },
		{ type = Identifier     , name = "name"           },
		{ type = VersionSpec    , name = "version"        },
		{ type = IDLType        , name = "type"           },
		{ type = AttributeMode  , name = "mode"           },
		{ type = ExceptionDefSeq, name = "get_exceptions" },
		{ type = ExceptionDefSeq, name = "set_exceptions" },
	},
}

ExtInterfaceDef.base_interfaces = { InterfaceDef, InterfaceAttrExtension }

Visibility = typedef{ short }

ValueMember = struct{
	{ type = Identifier  , name = "name"       },
	{ type = RepositoryId, name = "id"         },
	{ type = RepositoryId, name = "defined_in" },
	{ type = VersionSpec , name = "version"    },
	{ type = TypeCode    , name = "type"       },
	{ type = IDLType     , name = "type_def"   },
	{ type = Visibility  , name = "access"     },
}
ValueMemberSeq = typedef{ sequence{ValueMember} }

ValueMemberDef = interface{ Contained,
	members = {
		type     = attribute{ TypeCode, readonly = true },
		type_def = attribute{ IDLType },
		access   = attribute{ Visibility },
	},
}

ValueDef.base_interfaces = { Container, Contained, IDLType }

-- read/write interface

ValueDef.members.supported_interfaces = attribute{ InterfaceDefSeq }
ValueDef.members.initializers         = attribute{ InitializerSeq  }
ValueDef.members.base_value           = attribute{ ValueDef        }
ValueDef.members.abstract_base_values = attribute{ ValueDefSeq     }
ValueDef.members.is_abstract          = attribute{ boolean         }
ValueDef.members.is_custom            = attribute{ boolean         }
ValueDef.members.is_truncatable       = attribute{ boolean         }

-- read interface

ValueDef.members.is_a = operation{
	result = boolean,
	parameters = {{ type = RepositoryId, name = "id" }},
}
ValueDef.definitions.FullValueDescription = struct{
	{ type = Identifier        , name = "name"                 },
	{ type = RepositoryId      , name = "id"                   },
	{ type = boolean           , name = "is_abstract"          },
	{ type = boolean           , name = "is_custom"            },
	{ type = RepositoryId      , name = "defined_in"           },
	{ type = VersionSpec       , name = "version"              },
	{ type = OpDescriptionSeq  , name = "operations"           },
	{ type = AttrDescriptionSeq, name = "attributes"           },
	{ type = ValueMemberSeq    , name = "members"              },
	{ type = InitializerSeq    , name = "initializers"         },
	{ type = RepositoryIdSeq   , name = "supported_interfaces" },
	{ type = RepositoryIdSeq   , name = "abstract_base_values" },
	{ type = boolean           , name = "is_truncatable"       },
	{ type = RepositoryId      , name = "base_value"           },
	{ type = TypeCode          , name = "type"                 },
}
ValueDef.members.describe_value = operation{
	result = ValueDef.definitions.FullValueDescription,
}

-- write interface

ValueDef.members.create_value_member = operation{
	result = ValueMemberDef,
	parameters = {
		{ type = RepositoryId, name = "id"      },
		{ type = Identifier  , name = "name"    },
		{ type = VersionSpec , name = "version" },
		{ type = IDLType     , name = "type"    },
		{ type = Visibility  , name = "access"  },
	},
}
ValueDef.members.create_attribute = operation{
	result = AttributeDef,
	parameters = {
		{ type = RepositoryId , name = "id"      },
		{ type = Identifier   , name = "name"    },
		{ type = VersionSpec  , name = "version" },
		{ type = IDLType      , name = "type"    },
		{ type = AttributeMode, name = "mode"    },
	},
}
ValueDef.members.create_operation = operation{
	result = OperationDef,
	parameters = {
		{ type = RepositoryId     , name = "id"         },
		{ type = Identifier       , name = "name"       },
		{ type = VersionSpec      , name = "version"    },
		{ type = IDLType          , name = "result"     },
		{ type = OperationMode    , name = "mode"       },
		{ type = ParDescriptionSeq, name = "params"     },
		{ type = ExceptionDefSeq  , name = "exceptions" },
		{ type = ContextIdSeq     , name = "contexts"   },
	},
}

ValueDescription = struct{
	{ type = Identifier     , name = "name"                 },
	{ type = RepositoryId   , name = "id"                   },
	{ type = boolean        , name = "is_abstract"          },
	{ type = boolean        , name = "is_custom"            },
	{ type = RepositoryId   , name = "defined_in"           },
	{ type = VersionSpec    , name = "version"              },
	{ type = RepositoryIdSeq, name = "supported_interfaces" },
	{ type = RepositoryIdSeq, name = "abstract_base_values" },
	{ type = boolean        , name = "is_truncatable"       },
	{ type = RepositoryId   , name = "base_value"           },
}

ExtValueDef.base_interfaces = { ValueDef }

-- read/write interface

ExtValueDef.members.ext_initializers = attribute{ ExtInitializerSeq }

-- read interface

ExtValueDef.definitions.ExtFullValueDescription = struct{
	{ type = Identifier           , name = "name"                 },
	{ type = RepositoryId         , name = "id"                   },
	{ type = boolean              , name = "is_abstract"          },
	{ type = boolean              , name = "is_custom"            },
	{ type = RepositoryId         , name = "defined_in"           },
	{ type = VersionSpec          , name = "version"              },
	{ type = OpDescriptionSeq     , name = "operations"           },
	{ type = ExtAttrDescriptionSeq, name = "attributes"           },
	{ type = ValueMemberSeq       , name = "members"              },
	{ type = ExtInitializerSeq    , name = "initializers"         },
	{ type = RepositoryIdSeq      , name = "supported_interfaces" },
	{ type = RepositoryIdSeq      , name = "abstract_base_values" },
	{ type = boolean              , name = "is_truncatable"       },
	{ type = RepositoryId         , name = "base_value"           },
	{ type = TypeCode             , name = "type"                 },
}
ExtValueDef.members.describe_ext_value = operation{
	result = ExtValueDef.definitions.ExtFullValueDescription,
}

-- write interface

ExtValueDef.members.create_ext_attribute = operation{
	result = ExtAttributeDef,
	parameters = {
		{ type = RepositoryId   , name = "id"             },
		{ type = Identifier     , name = "name"           },
		{ type = VersionSpec    , name = "version"        },
		{ type = IDLType        , name = "type"           },
		{ type = AttributeMode  , name = "mode"           },
		{ type = ExceptionDefSeq, name = "get_exceptions" },
		{ type = ExceptionDefSeq, name = "set_exceptions" },
	},
}

ValueBoxDef.base_interfaces = { TypedefDef }
ValueBoxDef.members.original_type_def = attribute{ IDLType }

AbstractInterfaceDef.base_interfaces    = { InterfaceDef }
ExtAbstractInterfaceDef.base_interfaces = { AbstractInterfaceDef, InterfaceAttrExtension }
LocalInterfaceDef.base_interfaces       = { InterfaceDef }
ExtLocalInterfaceDef.base_interfaces    = { LocalInterfaceDef, InterfaceAttrExtension }
