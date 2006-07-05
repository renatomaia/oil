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
local print        = print

local table = require "table" require "loop.table"
local oo          = require "oil.oo"

module ("oil.manager", oo.class)                                                --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local assert      = require "oil.assert"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

ObjectManager = oo.class()

function ObjectManager:__init(manager)
	if not manager.ifaces then manager.ifaces = {} end -- maps repIDs to interfaces
	self.proxy = manager.proxy
	--self.ObjectInterface = self.proxy:getObjectInterface() 
	--manager.classes = { -- maps repIDs to proxy classes
	--	[self.ObjectInterface.repID] = self.proxy:class(self.ObjectInterface, manager),
	--}
	return oo.rawnew(self, manager)
end

function ObjectManager:getclass(repid)                                          --[[VERBOSE]] verbose:manager(true, "getting proxy class for ", repid)
	local class = self.classes[repid]
	if not class then                                                             --[[VERBOSE]] verbose:manager("attempt to create proxy class")
		local iface = self:getiface(repid)
		if iface then                                                               --[[VERBOSE]] verbose:manager(true, "creating managed proxy class")
			class = self.proxy:class(iface, self)
			self.classes[repid] = class                                               --[[VERBOSE]] verbose:manager(false)
		end
	end                                                                           --[[VERBOSE]] verbose:manager(false)
	return class
end

function ObjectManager:getiface(repid)                                          --[[VERBOSE]] verbose:manager(true, "getting interface ", repid)
	local iface = self.ifaces[repid]
	if not iface and self.ir then                                                 --[[VERBOSE]] verbose:manager(true, "looking on remote IR")
		iface = self.ir:lookup_id(repid)                                            --[[VERBOSE]] verbose:manager(false)
		if iface then                                                               --[[VERBOSE]] verbose:manager(true, "creating remote interface definition")
			iface = self.proxy:interface(
				iface:_narrow("IDL:omg.org/CORBA/InterfaceDef:1.0")
			)                                                                         --[[VERBOSE]] verbose:manager(false)
			self.ifaces[repid] = iface
		end
	end                                                                           --[[VERBOSE]] verbose:manager(false)
	return iface
end

function ObjectManager:putiface(def)
	assert.type(def, "idlinterface", "interface")
	local repID = def.repID
	assert.type(repID, "string", "interface repository ID")

	local interface = rawget(self.ifaces, repID)
	if interface ~= def then
		if interface then                                                           --[[VERBOSE]] verbose:manager("replace definition of ", repID)
			-- redefine interface members and class
			table.clear(interface)
			table.copy(def, interface)
			setmetatable(interface, getmetatable(def))
			
			proxyclass = rawget(self.classes, repID)
			if proxyclass then                                                        --[[VERBOSE]] verbose:manager("replace proxy class of ", repID)
				-- TODO: reset proxy class members, so new operation stubs will be created
				local handlers = proxyclass._handlers
				table.clear(proxyclass)
				proxyclass._iface = interface
				proxyclass._imanager = self
				proxyclass._handlers = handlers
				-- TODO: [nogara] Are these direct references really necessary?
				proxyclass.__index = proxy.Object.__index
				proxyclass.__newindex = proxy.Object.__newindex
			end
		else                                                                        --[[VERBOSE]] verbose:manager("register definition of ", repID)
			interface = def
			self.ifaces[repID] = interface
		end
	end
	return interface
end

function ObjectManager:resolve(ior, iface)
	local class
	if type(iface) == "table" then                                                --[[VERBOSE]] verbose:manager(true, "interface supplied for resolving object")
		iface = self:putiface(iface)
		iface = iface.repID                                                         --[[VERBOSE]] verbose:manager(false)
	end                                                                           --[[VERBOSE]] verbose:manager(true, "retrieving proxy class to resolve object")
	class = self:getclass(iface) or self:getclass(ior._type_id)                   --[[VERBOSE]] verbose:manager(false)
	if not class then
		assert.illegal(iface, "interface, unable to get definition", "MARSHALL")
	end
	return class(ior)
end

function new(self, ifaces)
	return ObjectManager{ ifaces = ifaces }
end
