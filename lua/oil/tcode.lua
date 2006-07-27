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
-- Title  : Serialization of pseudo-object type (TypeCodes)                   --
-- Authors: Noemi Rodriquez       <noemi@inf.puc-rio.br>                      --
--          Roberto Ierusalimschy <roberto@inf.puc-rio.br>                    --
--          Renato Cerqueira      <rcerq@inf.puc-rio.br>                      --
--          Pedro Miller          <miller@inf.puc-rio.br>                     --
--          Reinaldo Mello        <rmello@inf.puc-rio.br>                     --
--          Luiz Nogara           <nogara@inf.puc-rio.br>                     --
--          Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   unmarshall(buffer)      Unmarshalls a TypeCode from buffer               --
--   marshall(buffer, value) Marshalls TypeCode value into buffer             --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   This module is logically part of CDR module, however it is separated to  --
--   provide better reading of OiL source code.                               --
--                                                                            --
--   See section 15.3.5 of CORBA 3.0 specification.                           --
--------------------------------------------------------------------------------

local require = require
local ipairs  = ipairs

module "oil.tcode"                                                              --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local assert  = require "oil.assert"
local IDL     = require "oil.idl"
local cdr     = require "oil.cdr"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local UnionLabelInfo = {name = "label"}

--------------------------------------------------------------------------------
-- TypeCode information --------------------------------------------------------

-- NOTE: Description of type code categories, which is defined by field type
--	empty  : no further parameters are necessary to specify the associated
--           type.
--	simple : parameters that specify the associated type are defined as a
--           sequence of values.
--	complex: parameters that specify the associated type are defined as a
--           structure defined in IDL that is stored in a encapsulated octet
--           sequence (i.e. which endianess may differ).

local TypeCodeInfo = {
	[0]  = {name = "null"     , type = "empty", idl = IDL.null     , unhandled = true}, 
	[1]  = {name = "void"     , type = "empty", idl = IDL.void     }, 
	[2]  = {name = "short"    , type = "empty", idl = IDL.short    },
	[3]  = {name = "long"     , type = "empty", idl = IDL.long     },
	[4]  = {name = "ushort"   , type = "empty", idl = IDL.ushort   },
	[5]  = {name = "ulong"    , type = "empty", idl = IDL.ulong    },
	[6]  = {name = "float"    , type = "empty", idl = IDL.float    },
	[7]  = {name = "double"   , type = "empty", idl = IDL.double   },
	[8]  = {name = "boolean"  , type = "empty", idl = IDL.boolean  },
	[9]  = {name = "char"     , type = "empty", idl = IDL.char     },
	[10] = {name = "octet"    , type = "empty", idl = IDL.octet    },
	[11] = {name = "any"      , type = "empty", idl = IDL.any      },
	[12] = {name = "TypeCode" , type = "empty", idl = IDL.TypeCode },
	[13] = {name = "Principal", type = "empty", idl = IDL.Principal, unhandled = true},

	[14] = {name = "Object", type = "complex",
		parameters = IDL.struct{
			{name = "repID", type = IDL.string},
			{name = "name" , type = IDL.string},
		},
	},
	[15] = {name = "struct", type = "complex",
		parameters = IDL.struct{
			{name = "repID" , type = IDL.string},
			{name = "name"  , type = IDL.string},
			{name = "fields", type = IDL.sequence{
				IDL.struct{
					{name = "name", type = IDL.string},
					{name = "type", type = IDL.TypeCode}
				},
			}},
		},
	},
	[16] = {name = "union", type = "complex",
		parameters = IDL.struct{
			{name = "repID"  , type = IDL.string  },
			{name = "name"   , type = IDL.string  },
			{name = "switch" , type = IDL.TypeCode},
			{name = "default", type = IDL.long    },
		},
		mutable = {
			{name = "options", type = IDL.sequence{
				IDL.struct{
					UnionLabelInfo, -- NOTE: depends on field 'switch'.
					{name = "name" , type = IDL.string  },
					{name = "type" , type = IDL.TypeCode},
				},
			}},
			setup = function(self, union)
				UnionLabelInfo.type = union.switch
				return self
			end,
		},
	},
	[17] = {name = "enum", type = "complex",
		parameters = IDL.struct{
			{name = "repID"     , type = IDL.string              },
			{name = "name"      , type = IDL.string              },
			{name = "enumvalues", type = IDL.sequence{IDL.string}},
		}
	},
	[18] = {name = "string", type = "simple", idl = IDL.string,
		parameters = {
			{name = "maxlength", type = IDL.ulong}
		},
	},
	[19] = {name = "sequence", type = "complex",
		parameters = IDL.struct{
			{name = "elementtype", type = IDL.TypeCode},
			{name = "maxlength"  , type = IDL.ulong   },
		}
	},
	[20] = {name = "array", type = "complex",
		parameters = IDL.struct{
			{name = "elementtype", type = IDL.TypeCode},
			{name = "length"     , type = IDL.ulong   },
		}
		},
	[21] = {name = "typedef", type = "complex",
		parameters = IDL.struct{
			{name = "repID", type = IDL.string  },
			{name = "name" , type = IDL.string  },
			{name = "type" , type = IDL.TypeCode},
		},
	},
	[22] = {name = "except", type = "complex",
		parameters = IDL.struct{
			{name = "repID", type = IDL.string},
			{name = "name",  type = IDL.string},
			{name = "members", type = IDL.sequence{
				IDL.struct{
					{name = "name", type = IDL.string  },
					{name = "type", type = IDL.TypeCode},
				},
			}},
		},
	},
	
	[23] = {name = "longlong"  , type = "empty", unhandled = true}, 
	[24] = {name = "ulonglong" , type = "empty", unhandled = true},
	[25] = {name = "longdouble", type = "empty", unhandled = true},
	[26] = {name = "wchar"     , type = "empty", unhandled = true},
	
	[27] = {name = "wstring", type = "simple", unhandled = true, kind = "wstring",
		parameters = {
			{name = "maxlength", type = IDL.ulong},
		},
	},
	[28] = {name = "fixed", type = "simple", unhandled = true, kind = "fixed",
		parameters = {
			{name = "digits", type = IDL.ushort},
			{name = "scale" , type = IDL.short },
		},
	},
	
	[29] = {name = "value"             , type = "complex", unhandled = true},
	[30] = {name = "value_box"         , type = "complex", unhandled = true},
	[31] = {name = "native"            , type = "complex", unhandled = true},
	[32] = {name = "abstract_interface", type = "complex", unhandled = true},
	
	-- [0xffffffff] = {name="none", type = "simple"},
}

--------------------------------------------------------------------------------
-- TypeCode unmarshalling function ---------------------------------------------

function unmarshall(buffer)                                                     --[[VERBOSE]] verbose.unmarshallOf(IDL.TypeCode, value, buffer)
	local kind = buffer:ulong()
	local tcinfo = TypeCodeInfo[kind]
	
	if tcinfo == nil then assert.ilegal(kind, "type code", "MARSHALL") end        --[[VERBOSE]] verbose.unmarshall{"TypeCode defines a ", tcinfo.name}
	if tcinfo.unhandled then
		assert.ilegal(tcinfo.name, "supported type code", "MARSHALL")
	end
	
	if tcinfo.type == "simple" then
		
		-- NOTE: The string type is the only simple type being handled,
		--       therefore parameters are ignored.
		for _, param in ipairs(tcinfo.parameters) do                                --[[VERBOSE]] verbose.unmarshall{"[parameter ", param.name, "]"}
			buffer:get(param.type)
		end
		
	elseif tcinfo.type == "complex" then                                          --[[VERBOSE]] verbose.unmarshall{"[parameters encapsulation]"}
		
		local params = buffer:sequence(IDL.OctetSeq)
		buffer = cdr.ReadBuffer(params, true)                                       --[[VERBOSE]] verbose.unmarshall{"[parameters values]"}
		params = buffer:struct(tcinfo.parameters)
		if tcinfo.mutable then                                                      --[[VERBOSE]] verbose.unmarshall{"[mutable parameters values]"}
			for _, param in ipairs(tcinfo.mutable:setup(params)) do
				params[param.name] = buffer:get(param.type)
			end
		end                                                                         --[[VERBOSE]] verbose.unmarshall() -- done
		return IDL[tcinfo.name](params)
		
	end                                                                           --[[VERBOSE]] verbose.unmarshall() -- done
	
	return tcinfo.idl
end

--------------------------------------------------------------------------------
-- TypeCode marshalling function -----------------------------------------------

local TypeCodes = { interface = 14 }
for tcode, info in ipairs(TypeCodeInfo) do TypeCodes[info.name] = tcode end

function marshall(buffer, value)                                                --[[VERBOSE]] verbose.marshallOf(IDL.TypeCode, value, buffer)
	local kind   = TypeCodes[value._type]
	local tcinfo = TypeCodeInfo[kind]
	
	if not kind then assert.ilegal(value, "IDL type", "MARSHALL") end
	
	buffer:ulong(kind)
	
	if tcinfo.type == "simple" then
		
		for _, param in ipairs(tcinfo.parameters) do                                --[[VERBOSE]] verbose.marshall{"[parameter ", param.name, "]"}
			buffer:put(value[param.name], param.type)
		end
		
	elseif tcinfo.type == "complex" then
		
		local temp = cdr.WriteBuffer(true)                                          --[[VERBOSE]] verbose.marshall{"[parameters values]"}
		temp:struct(value, tcinfo.parameters)
		if tcinfo.mutable then                                                      --[[VERBOSE]] verbose.marshall{"[mutable parameters values]"}
			for _, param in ipairs(tcinfo.mutable:setup(value)) do
				temp:put(value[param.name], param.type)
			end
		end                                                                         --[[VERBOSE]] verbose.marshall{"[parameters encapsulation]"}
		buffer:sequence(temp:getdata(), IDL.OctetSeq)
		
	end                                                                           --[[VERBOSE]] verbose.marshall() -- done
end
