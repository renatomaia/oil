-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : IDL Interface Indexer
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local ipairs = _G.ipairs

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"
local operation = idl.operation

local Indexer = class{
	patterns = { "^_([gs]et)_(.+)$" },
	builders = {},
}

--------------------------------------------------------------------------------
-- Internal Functions ----------------------------------------------------------

function Indexer:findmember(interface, name)
	for interface in interface:hierarchy() do
		local contained = interface.definitions[name]
		if
			contained and
			(contained._type == "operation" or contained._type == "attribute")
		then
			return contained, interface
		end
	end
end

function Indexer.builders:get(attribute, interface, opname, attribop)
	if attribute._type == "attribute" then
		local attribname = attribute.name
		return operation{ attribute = attribute, attribop = attribop,
			name = opname,
			defined_in = interface,
			result = attribute.type,
			implementation = function(self)
				return self[attribname]
			end,
		}
	end
end

function Indexer.builders:set(attribute, interface, opname, attribop)
	if attribute._type == "attribute" then
		local attribname = attribute.name
		return operation{ attribute = attribute, attribop = attribop,
			name = opname,
			defined_in = interface,
			parameters = { {type = attribute.type, name = "value"} },
			implementation = function(self, value)
				self[attribname] = value
			end,
		}
	end
end

--------------------------------------------------------------------------------
-- Interface Operations --------------------------------------------------------

function Indexer:valueof(interface, name)
	local member = self:findmember(interface, name)
	if member == nil then
		local action
		for _, pattern in ipairs(self.patterns) do
			action, member = name:match(pattern)
			if action then
				member, interface = self:findmember(interface, member)
				if member ~= nil then
					member = self.builders[action](self, member, interface, name, action)
					if member then
						break
					end
				end
			end
		end
	end
	return member
end

return Indexer
