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
-- Title  : Management of proxies and translation of IOR into OiL proxies     --
-- Authors: Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   new()              Creates a new ObjectManager instance                  --
--                                                                            --
-- ObjectManager Interface:                                                   --
--   putiface(iface)    Put an interface definition in repository             --
--   getiface(repID)    Get the interface defined by repID from repository    --
--   getclass(repID)    Get class of proxies for objects of interface of repID--
--   resolve(ior,iface) Translates IOR into a proxy of interface iface        --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local type         = type
local setmetatable = setmetatable
local require      = require
local getmetatable = getmetatable
local rawget       = rawget

local table = require "table" require "loop.utils"

module "oil.manager"                                                            --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local oo          = require "oil.oo"
local assert      = require "oil.assert"
local proxy       = require "oil.proxy"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

ObjectManager = oo.class()

local ObjectInterface = proxy.Object._iface

function ObjectManager:__init(manager)
	if not manager.ifaces then manager.ifaces = {} end -- maps repIDs to interfaces
	manager.classes = { -- maps repIDs to proxy classes
		[ObjectInterface.repID] = proxy.class(ObjectInterface, manager),
	}
	return oo.rawnew(self, manager)
end

function ObjectManager:getclass(repid)                                          --[[VERBOSE]] verbose.manager({"getting proxy class for ", repid}, true)
	local class = self.classes[repid]
	if not class then                                                             --[[VERBOSE]] verbose.manager("attempt to create proxy class")
		local iface = self:getiface(repid)
		if iface then                                                               --[[VERBOSE]] verbose.manager("creating managed proxy class", true)
			class = proxy.class(iface, self)
			self.classes[repid] = class                                               --[[VERBOSE]] verbose.manager()
		end
	end                                                                           --[[VERBOSE]] verbose.manager()
	return class
end

function ObjectManager:getiface(repid)                                          --[[VERBOSE]] verbose.manager({"getting interface ", repid}, true)
	local iface = self.ifaces[repid]
	if not iface and self.ir then                                                 --[[VERBOSE]] verbose.manager("looking on remote IR", true)
		iface = self.ir:lookup_id(repid)                                            --[[VERBOSE]] verbose.manager()
		if iface then                                                               --[[VERBOSE]] verbose.manager("creating remote interface definition", true)
			iface = proxy.interface(
				iface:_narrow("IDL:omg.org/CORBA/InterfaceDef:1.0")
			)                                                                         --[[VERBOSE]] verbose.manager()
			self.ifaces[repid] = iface
		end
	end                                                                           --[[VERBOSE]] verbose.manager()
	return iface
end

function ObjectManager:putiface(def)
	assert.type(def, "idlinterface", "interface")
	local repID = def.repID
	assert.type(repID, "string", "interface repository ID")

	local interface = rawget(self.ifaces, repID)
	if interface ~= def then
		if interface then                                                           --[[VERBOSE]] verbose.manager{"replace definition of ", repID}
			-- redefine interface members and class
			table.clear(interface)
			table.copy(def, interface)
			setmetatable(interface, getmetatable(def))
			
			proxyclass = rawget(self.classes, repID)
			if proxyclass then                                                        --[[VERBOSE]] verbose.manager{"replace proxy class of ", repID}
				-- TODO: reset proxy class members, so new operation stubs will be created
				local handlers = proxyclass._handlers
				table.clear(proxyclass)
				proxyclass._iface = interface
				proxyclass._manager = self
				proxyclass._handlers = handlers
				proxyclass.__index = proxy.Object.__index
				proxyclass.__newindex = proxy.Object.__newindex
			end
		else                                                                        --[[VERBOSE]] verbose.manager{"register definition of ", repID}
			interface = def
			self.ifaces[repID] = interface
		end
	end
	return interface
end

local GenericProxy = oo.class()
function ObjectManager:resolve(ior, iface)
	local class
	if type(iface) == "table" then                                                --[[VERBOSE]] verbose.manager("interface supplied for resolving object", true)
		iface = self:putiface(iface)
		iface = iface.repID                                                         --[[VERBOSE]] verbose.manager()
	end                                                                           --[[VERBOSE]] verbose.manager("retrieving proxy class to resolve object", true)
	class = self:getclass(iface) or self:getclass(ior._type_id)                   --[[VERBOSE]] verbose.manager()
	if not class then
		assert.ilegal(iface, "interface, unable to get definition", "MARSHALL")
	end
	return class(ior)
end

function new(ifaces)
	return ObjectManager{ ifaces = ifaces }
end