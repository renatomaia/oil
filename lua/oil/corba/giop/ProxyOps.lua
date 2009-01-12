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
-- Title  : Client-Side Interface Indexer                                     --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- indexer:Facet
-- 	interface:table typeof(reference:table)
-- 	member:table, [islocal:function], [cached:boolean] valueof(interface:table, name:string)
-- 
-- members:Receptacle
-- 	member:table valueof(interface:table, name:string)
-- 
-- requester:Receptacle
-- 	[request:object], [except:table] newrequest(reference:table, operation, args...)
-- 	[success:boolean], [except:table] getreply(request:object, operation, args...)
-- 
-- types:Receptacle
-- 	[type:table] register(definition:object)
-- 	[type:table] resolve(type:string)
-- 	[type:table] lookup_id(repid:string)
-- 
-- profiler:HashReceptacle
-- 	result:boolean equivalent(profile1:string, profile2:string)
--------------------------------------------------------------------------------

local ipairs = ipairs

local oo        = require "oil.oo"
local assert    = require "oil.assert"
local idl       = require "oil.corba.idl"
local giop      = require "oil.corba.giop"
local Indexer   = require "oil.corba.giop.Indexer"                              --[[VERBOSE]] local verbose = require "oil.verbose"

module"oil.corba.giop.ProxyOps"

oo.class(_M, Indexer)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

RequestWrapper = oo.class()

local function contentswrapper(self, ...)
	local request = self.request
	return self.handler(request, request:contents(...))
end

function RequestWrapper:__index(field)
	local request = self.request
	if field == "contents" and request.contents then
		return contentswrapper
	end
	return request[field]
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function context(component, context)
	local localops = {}
	------------------------------------------------------------------------------
	local function nonexistent()
		return true, true
	end
	
	local function handler(request, success, result)
		if
			not success and
			( result.exception_id == "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0" or
			  result.reason == "closed" )
		then
			success, result = true, true
		end
		return success, result
	end
	
	local _non_existent = giop.ObjectOperations._non_existent
	function localops:_non_existent()
		local result, except = context.requester:newrequest(self.__reference, _non_existent)
		if result then
			result = RequestWrapper{
				request = result,
				handler = handler,
			}
		elseif except.reason == "connect" or except.reason == "closed" then
			result.contents = nonexistent
		end
		return result, except
	end
	------------------------------------------------------------------------------
	local function narrowed(self)
		return true, self[1]
	end
	
	local function handler(request, success, result)
		if success then
			result = context.types:lookup_id(result:_get_id()) or
			         context.types:register(result)
			result = context.proxies:proxyto(request.reference, result)
		end
		return success, result
	end
	
	local _interface = giop.ObjectOperations._interface
	function localops:_narrow(iface)
		local result, except
		if iface == nil then
			result, except = context.requester:newrequest(self.__reference, _interface)
			if result then
				result = RequestWrapper{
					reference = self.__reference,
					request = result,
					handler = handler,
				}
			end
		else
			result, except = context.types:resolve(iface)
			if result then
				result, except = context.proxies:proxyto(self.__reference, result)
			end
			if result then
				result = { result, contents = narrowed }
			end
		end
		return result, except
	end
	------------------------------------------------------------------------------
	local IsEquivalentReply = { contents = function() return true end }
	local NotEquivalentReply = { contents = function() return false end }
	function localops:_is_equivalent(proxy)
		local reference = proxy.__reference
		local ref = self.__reference
		local tags = {}
		for _, profile in ipairs(reference.profiles) do
			tags[profile.tag] = profile
		end
		for _, profile in ipairs(ref.profiles) do
			local tag = profile.tag
			local other = tags[tag]
			if other then
				local profiler = context.profiler[tag]
				if
					profiler and
					profiler:equivalent(profile.profile_data, other.profile_data)
				then
					return IsEquivalentReply
				end
			end
		end
		return NotEquivalentReply
	end
	
	component.localops = localops
	component.context = context
end

function importinterfaceof(self, reference)
	local context = self.context
	local operation = giop.ObjectOperations._interface
	local result, except = context.requester:newrequest(reference, operation)
	if result then
		local request = result
		result, except = context.requester:getreply(request)
		if result then
			result, except = request:contents()
			if result then
				result = context.types:lookup_id(except:_get_id()) or
				         context.types:register(except)
			end
		end
	end
	return result or assert.exception(except)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function typeof(self, reference)
	local type = reference.type_id
	local types = self.context.types
	return self.context.types:lookup_id(type) or
	       self:importinterfaceof(reference)
end

function valueof(self, interface, name)
	local member = Indexer.valueof(self, interface, name)
	if member and member._type ~= "operation" then
		member = nil
	end
	return member, self.localops[name], true
end
