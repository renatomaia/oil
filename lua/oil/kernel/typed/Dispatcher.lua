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
-- Title  : Object Request Dispatcher                                         --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- objects:Facet
-- 	object:object register(impl:object, objectkey:string)
-- 	impl:object unregister(objectkey:string)
-- 
-- dispatcher:Facet
-- 	success:boolean, [except:table]|results... dispatch(objectkey:string, operation:string|function, params...)
-- 
-- indexer:Receptacle
-- 	[member:string], [implementation:function] valueof(objectkey:string, operation:string)
--------------------------------------------------------------------------------


local oo         = require "oil.oo"
local Exception  = require "oil.Exception"
local Dispatcher = require "oil.kernel.base.Dispatcher"                         --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.typed.Dispatcher"

oo.class(_M, Dispatcher)

context = false

--------------------------------------------------------------------------------
-- Objects facet

function register(self, key, impl, type)
	local entry = self.map[key]
	if entry == nil
	or entry.object ~= impl
	or entry.type ~= type
	then
		return Dispatcher.register(self, key, { object = impl, type = type })
	end
	return true
end

function unregister(self, key)
	local result, except = Dispatcher.unregister(self, key)
	if result then result, except = result.object, result.type end
	return result, except
end

function retrieve(self, key)
	local result, except = Dispatcher.retrieve(self, key)
	if result then result, except = result.object, result.type end
	return result, except
end

--------------------------------------------------------------------------------
-- Dispatcher facet

function dispatch(self, key, operation, default, ...)
	local entry = self.map[key]
	if entry then
		local member = self.context.indexer:valueof(entry.type, operation)
		if member then
			local object = entry.object
			local method = object[operation]
			if method == nil then
				object = entry
				method = default
			end
			if method then                                                            --[[VERBOSE]] verbose:dispatcher("dispatching operation ",entry.object,":",operation, ...)
				return self.pcall(method, object, ...)
			else
				return false, Exception{
					reason = "noimplement",
					message = "no implementation for operation of object with key",
					operation = operation,
					object = object,
					type = entry.type,
					key = key,
				}
			end
		else
			return false, Exception{
				reason = "badoperation",
				message = "operation is illegal for object with key",
				operation = operation,
				type = entry.type,
				key = key,
			}
		end
	else
		return false, Exception{
			reason = "badkey",
			message = "no object with key",
			key = key,
		}
	end
end
