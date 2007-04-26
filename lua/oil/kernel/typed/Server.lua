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
-- Title  : Server-Side Broker                                                --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- broker:Facet
-- 	[configs:table], [except:table] initialize([configs:table])
-- 	servant:object object(impl:object, [objectkey:string])
-- 	reference:string tostring(servant:object)
-- 	success:boolean, [except:table] pending()
-- 	success:boolean, [except:table] step()
-- 	success:boolean, [except:table] run()
-- 	success:boolean, [except:table] shutdown()
-- 
-- objects:Receptacle
-- 	object:object register(impl:object, key:string)
-- 	impl:object unregister(key:string)
-- 	impl:object retrieve(key:string)
-- 
-- acceptor:Receptacle
-- 	configs:table, [except:table] setup([configs:table])
-- 	success:boolean, [except:table] hasrequest(configs:table)
-- 	success:boolean, [except:table] acceptone(configs:table)
-- 	success:boolean, [except:table] acceptall(configs:table)
-- 	success:boolean, [except:table] halt(configs:table)
-- 
-- references:Receptacle
-- 	reference:table referenceto(objectkey:string, accesspointinfo:table...)
-- 	stringfiedref:string encode(reference:table)
-- 
-- types:Receptacle
-- 	type:table resolve(type:string)
--------------------------------------------------------------------------------

local rawget = rawget
local type   = type

local table = require "loop.table"

local oo     = require "oil.oo"
local Server = require "oil.kernel.base.Server"                                 --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.kernel.typed.Server"

oo.class(_M, Server)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local KeyFmt = "\0%s%s"

function object(self, object, key, type)
	local context = self.context
	local result, except = context.types:resolve(type)
	if result then
		key = key or KeyFmt:format(self:hashof(object), self:hashof(result))
		result, except = context.mapper:register(result, key)
		if result then
			result, except = context.objects:register(object, key)
			if result then
				object = result
				result, except = context.references:referenceto(key, self.config)
				if result then
					result, except = table.copy(result, object)
				end
			end
		end
	end
	return result, except
end

function remove(self, key, objtype)
	local temp = type(key)
	if temp == "table" then
		key = rawget(key, "_key") or key
	end
	if temp ~= "string" then
		objtype, temp = self.context.types:resolve(objtype)
		if objtype then
			key = KeyFmt:format(self:hashof(key), self:hashof(objtype))
		else
			return objtype, temp
		end
	end
	return self.context.objects:unregister(key)
end
