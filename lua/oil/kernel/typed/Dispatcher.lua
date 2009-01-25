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
-- dispatcher:Facet
-- 	success:boolean, [except:table]|results... dispatch(objectkey:string, operation:string|function, params...)
-- 
-- indexer:Receptacle
-- 	[member:string], [implementation:function] valueof(objectkey:string, operation:string)
--------------------------------------------------------------------------------

local unpack = unpack

local oo         = require "oil.oo"
local Exception  = require "oil.Exception"
local Dispatcher = require "oil.kernel.base.Dispatcher"                         --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.typed.Dispatcher"

oo.class(_M, Dispatcher)

context = false

--------------------------------------------------------------------------------
-- Dispatcher facet

function dispatch(self, request)
	local context = self.context
	local object, type = context.servants:retrieve(request.target)
	if object then
		local operation = request.operation
		if context.indexer:valueof(type, operation) then
			local method = object[operation]
			if method == nil then
				object = context.servants.map[request.target] -- TODO:[maia] this is ugly!
				method = request.defaultimpl
			end
			if method then                                                            --[[VERBOSE]] verbose:dispatcher("dispatching operation ",object,":",operation, unpack(request, 1, request.n))
				self:setresults(request, self.pcall(method, object,
				                                    unpack(request, 1, request.n)))
			else
				self:setresults(false, Exception{
					reason = "noimplement",
					message = "no implementation for operation of object with key",
					operation = operation,
					object = object,
					type = entry.type,
					key = key,
				})
			end
		else
			self:setresults(false, Exception{
				reason = "badoperation",
				message = "operation is illegal for object with key",
				operation = operation,
				type = entry.type,
				key = key,
			})
		end
	else
		self:setresults(false, Exception{
			reason = "badkey",
			message = "no object with key",
			key = key,
		})
	end
	return true
end
