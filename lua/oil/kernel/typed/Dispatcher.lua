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
		local opname = request.operation
		local opinfo = context.indexer:valueof(type, opname)
		if opinfo then
			local method = object[opname] or opinfo.implementation
			if method then                                                            --[[VERBOSE]] verbose:dispatcher("dispatching operation ",object,":",opname, unpack(request, 1, request.n))
				self:setresults(request, self.pcall(method, object,
				                                    unpack(request, 1, request.n)))
			else
				self:setresults(false, Exception{
					reason = "noimplement",
					message = "no implementation for operation of object with key",
					operationdescription = opinfo,
					operation = opname,
					object = object,
					type = type,
					key = key,
				})
			end
		else
			self:setresults(false, Exception{
				reason = "badoperation",
				message = "operation is illegal for object with key",
				operation = opname,
				object = object,
				type = type,
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
